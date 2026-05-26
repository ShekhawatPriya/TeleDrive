import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/media/gallery_media_scanner.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import '../drive/drive_repository.dart';
import '../upload/upload_controller.dart';
import '../upload/upload_models.dart';
import 'app_settings_controller.dart';
import 'gallery_backup_asset_store.dart';
import 'gallery_backup_diagnostics.dart';

export 'gallery_backup_diagnostics.dart';

part 'gallery_backup_controller_helpers.dart';
part 'gallery_backup_scan.dart';

final galleryBackupControllerProvider =
    ChangeNotifierProvider<GalleryBackupController>((ref) {
      final controller = GalleryBackupController(
        settings: ref.read(appSettingsControllerProvider),
        auth: ref.read(authControllerProvider),
        uploads: ref.read(uploadControllerProvider),
        drive: ref.read(driveRepositoryProvider),
      );
      ref.onDispose(controller.dispose);
      controller.start();
      return controller;
    });

class GalleryBackupController extends ChangeNotifier {
  GalleryBackupController({
    required AppSettingsController settings,
    required AuthController auth,
    required UploadController uploads,
    required DriveRepository drive,
    GalleryMediaScanner scanner = const GalleryMediaScanner(),
    GalleryBackupAssetStore assetStore = const GalleryBackupAssetStore(),
  }) : _settings = settings,
       _auth = auth,
       _uploads = uploads,
       _drive = drive,
       _scanner = scanner,
       _assetStore = assetStore {
    _lastEnabled = _settings.state.galleryBackupEnabled;
    _settings.addListener(_handleSettingsChanged);
    _auth.addListener(_scheduleSoon);
  }

  static const _uuid = Uuid();
  static const _periodicScan = Duration(minutes: 15);
  static const _manualDelayedRescan = Duration(seconds: 8);
  static const _resumeScanThrottle = Duration(minutes: 2);

  final AppSettingsController _settings;
  final AuthController _auth;
  final UploadController _uploads;
  final DriveRepository _drive;
  final GalleryMediaScanner _scanner;
  final GalleryBackupAssetStore _assetStore;
  final Map<String, String> _folderIdCache = {};
  Timer? _timer;
  Timer? _debounce;
  Timer? _delayedRescan;
  bool _running = false;
  bool _lastEnabled = false;
  DateTime? _lastResumeScanAt;

  GalleryBackupDiagnostics diagnostics = const GalleryBackupDiagnostics();

  bool get running => _running;
  String? get lastError => diagnostics.lastError;

  void _emitChange() => notifyListeners();

  void start() {
    if (_settings.state.galleryBackupEnabled) _scheduleSoon();
    _timer = Timer.periodic(_periodicScan, (_) {
      unawaited(scanNow(reason: 'periodic'));
    });
  }

  Future<void> scanNow({
    String reason = 'manual',
    bool bypassThrottle = true,
    bool scheduleDelayedRescan = true,
  }) => _scanNow(
    reason: reason,
    bypassThrottle: bypassThrottle,
    scheduleDelayedRescan: scheduleDelayedRescan,
  );

  Future<void> handleAppResumed() async {
    if (!_settings.state.galleryBackupEnabled) return;
    final now = DateTime.now();
    if (_lastResumeScanAt != null &&
        now.difference(_lastResumeScanAt!) < _resumeScanThrottle) {
      return;
    }
    _lastResumeScanAt = now;
    await scanNow(
      reason: 'resume',
      bypassThrottle: false,
      scheduleDelayedRescan: true,
    );
  }

  void _handleSettingsChanged() {
    final enabled = _settings.state.galleryBackupEnabled;
    if (_lastEnabled == enabled) {
      if (enabled) _scheduleSoon();
      return;
    }
    _lastEnabled = enabled;
    if (enabled) {
      _scheduleSoon();
    } else {
      _debounce?.cancel();
      _delayedRescan?.cancel();
      unawaited(_uploads.pauseQueuedGalleryBackupItems());
    }
  }

  void _scheduleSoon() {
    if (!_settings.state.galleryBackupEnabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(scanNow(reason: 'settings', scheduleDelayedRescan: false));
    });
  }

  void _scheduleDelayedRescan() {
    _delayedRescan?.cancel();
    _delayedRescan = Timer(_manualDelayedRescan, () {
      unawaited(
        scanNow(
          reason: 'delayed_rescan',
          bypassThrottle: true,
          scheduleDelayedRescan: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_handleSettingsChanged);
    _auth.removeListener(_scheduleSoon);
    _timer?.cancel();
    _debounce?.cancel();
    _delayedRescan?.cancel();
    super.dispose();
  }
}
