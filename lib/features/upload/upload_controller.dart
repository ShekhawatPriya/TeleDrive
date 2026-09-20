import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../core/notifications/upload_notification_service.dart';
import '../../core/network/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/media/client_derivative_generator.dart';
import '../../core/telegram/pending_telegram_commit_queue.dart';
import '../../core/telegram/telegram_client_exceptions.dart';
import '../../core/telegram/telegram_client_models.dart';
import '../../core/telegram/telegram_transfer_service.dart';
import '../../core/utils/iterable_ext.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import '../profile/app_settings_controller.dart';
import '../profile/gallery_backup_asset_store.dart';
import 'upload_models.dart';
import 'upload_picker_helper.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';

part 'upload_controller/upload_state_sync.dart';
part 'upload_controller/upload_controller_helpers.dart';
part 'upload_controller/upload_public_actions.dart';
part 'upload_controller/upload_derivatives.dart';
part 'upload_controller/upload_direct.dart';
part 'upload_controller/upload_direct_file.dart';
part 'upload_controller/upload_queue.dart';

final uploadControllerProvider = ChangeNotifierProvider<UploadController>((
  ref,
) {
  return UploadController(
    ref.read(apiClientProvider),
    ref.read(driveControllerProvider),
    ref.read(appSettingsControllerProvider),
    ref.read(uploadNotificationServiceProvider),
    ref.read(authControllerProvider),
    ref.read(telegramTransferServiceProvider),
  );
});

class UploadController extends ChangeNotifier {
  UploadController(
    this._api,
    this._drive,
    this._settings,
    this._notifications,
    this._auth,
    this._telegram,
  ) {
    _settings.addListener(_handleSettingsChanged);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
  }

  static const maxFiles = 50;

  final ApiClient _api;
  final DriveController _drive;
  final AppSettingsController _settings;
  final UploadNotificationService _notifications;
  final AuthController _auth;
  final TelegramTransferService _telegram;
  final ClientDerivativeGenerator _derivatives =
      const ClientDerivativeGenerator();
  final PendingTelegramCommitQueue _pendingCommits =
      PendingTelegramCommitQueue();
  final GalleryBackupAssetStore _backupAssetStore =
      const GalleryBackupAssetStore();
  final _uuid = const Uuid();
  final Set<String> _runningLocalIds = {};
  Timer? _autoDismissTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String? _refreshedUploadSessionId;
  String? _notifiedSessionId;
  bool _disposed = false;
  bool _notifyScheduled = false;
  int _itemsVersion = 0;
  Timer? _optimisticSyncTimer;

  void _emitChange() {
    notifyListeners();
  }

  String? uploadSessionId;
  List<UploadItem> items = [];
  bool picking = false;
  bool uploading = false;
  bool sheetVisible = false;
  String? activeFolderId;
  String? error;

  int get uploadedCount =>
      items.where((i) => i.status == UploadStatus.uploaded).length;
  int get failedCount => items
      .where(
        (i) =>
            i.status == UploadStatus.failed ||
            i.status == UploadStatus.cancelled,
      )
      .length;
  int get activeCount => items.where(_isActive).length;
  bool get waitingForWifi =>
      items.any((i) => i.status == UploadStatus.waitingForWifi);
  Set<String> get activeGalleryBackupFingerprints => items
      .where(
        (i) =>
            i.clientSource == 'gallery_backup' &&
            i.backupFingerprint != null &&
            !_isTerminalStatus(i.status),
      )
      .map((i) => i.backupFingerprint!)
      .toSet();
  int get activeGalleryBackupQueueCount =>
      activeGalleryBackupFingerprints.length;
  bool get hasBlockingUploads =>
      uploading ||
      activeCount > 0 ||
      items.any(
        (i) => {
          UploadStatus.queued,
          UploadStatus.waitingForWifi,
          UploadStatus.preparingMetadata,
          UploadStatus.creatingThumbnail,
          UploadStatus.creatingPreview,
          UploadStatus.uploadingOriginalToTelegram,
          UploadStatus.uploadingThumbnailToTelegram,
          UploadStatus.uploadingPreviewToTelegram,
          UploadStatus.committingMetadata,
          UploadStatus.cancelling,
        }.contains(i.status),
      );

  UploadItemIdsSnapshot get itemIdsSnapshot => UploadItemIdsSnapshot(
    List<String>.unmodifiable(items.map((i) => i.localId)),
    _itemsVersion,
  );

  UploadSummary get summary {
    final count = items.length;
    var sumProgress = 0.0;
    var totalBytes = 0;
    var completedBytes = 0;
    var stillGeneratingThumbs = false;
    var allUploaded = count > 0;
    for (final item in items) {
      sumProgress += item.progress;
      totalBytes += item.size;
      completedBytes += (item.progress * item.size).round();
      if (item.status != UploadStatus.uploaded) allUploaded = false;
      if (item.status == UploadStatus.uploaded && !item.thumbnailReady) {
        final kind = detectFileKind(item.name, item.mimeType);
        if (kind == FileKind.image || kind == FileKind.video) {
          stillGeneratingThumbs = true;
        }
      }
    }
    final progressPermille = count == 0
        ? 0
        : (sumProgress * 1000 / count).round().clamp(0, 1000);
    return UploadSummary(
      sheetVisible: sheetVisible,
      itemCount: count,
      uploadedCount: uploadedCount,
      failedCount: failedCount,
      activeCount: activeCount,
      waitingForWifi: waitingForWifi,
      uploading: uploading,
      stillGeneratingThumbs: allUploaded && stillGeneratingThumbs,
      progressPermille: progressPermille,
      totalBytes: totalBytes,
      completedBytes: completedBytes,
    );
  }

  Future<void> pickFiles({String? folderId, BuildContext? context}) =>
      _pickFiles(folderId: folderId, context: context);

  Future<void> pickPhoto({String? folderId, BuildContext? context}) =>
      _pickPhoto(folderId: folderId, context: context);

  Future<void> pickPhotos({String? folderId, BuildContext? context}) =>
      _pickPhotos(folderId: folderId, context: context);

  Future<void> confirmUpload() => _confirmUpload();

  Future<void> enqueueGalleryBackupItems(List<UploadItem> backupItems) =>
      _enqueueGalleryBackupItems(backupItems);

  Future<void> pauseQueuedGalleryBackupItems() =>
      _pauseQueuedGalleryBackupItems();

  Future<void> cancelItem(String localId) => _cancelItem(localId);

  Future<void> cancelUpload() => _cancelUpload();

  Future<void> retryFailed() => _retryFailed();

  void removeFailed(String localId) => _removeFailed(localId);

  void dismiss() => _dismiss();

  void resetTerminalForAccountSwitch() => _resetTerminalForAccountSwitch();

  Future<void> enableMobileDataUploads() => _enableMobileDataUploads();
  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(_handleSettingsChanged);
    _connectivitySubscription?.cancel();
    _cancelCompletionTimers();
    _optimisticSyncTimer?.cancel();
    super.dispose();
  }
}
