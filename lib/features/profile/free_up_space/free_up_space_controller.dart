import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/media/gallery_media_scanner.dart';
import '../../auth/auth_controller.dart';
import '../../drive/drive_controller.dart';
import '../../drive/drive_repository.dart';
import '../../upload/upload_controller.dart';
import '../gallery_backup_asset_store.dart';

final freeUpSpaceControllerProvider =
    ChangeNotifierProvider<FreeUpSpaceController>((ref) {
      final controller = FreeUpSpaceController(
        auth: ref.read(authControllerProvider),
        uploads: ref.read(uploadControllerProvider),
        drive: ref.read(driveRepositoryProvider),
      );
      Future.microtask(controller.scan);
      return controller;
    });

@immutable
class FreeUpSpaceCandidate {
  const FreeUpSpaceCandidate({
    required this.fingerprint,
    required this.contentUri,
    required this.name,
    required this.sizeBytes,
    required this.mediaType,
    required this.mimeType,
    required this.modifiedAtMillis,
    required this.addedAtMillis,
    this.relativePath,
    this.thumbnailHintPath,
    required this.backendReason,
  });

  final String fingerprint;
  final String contentUri;
  final String name;
  final int sizeBytes;
  final String mediaType;
  final String mimeType;
  final int modifiedAtMillis;
  final int addedAtMillis;
  final String? relativePath;
  final String? thumbnailHintPath;
  final String backendReason;
}

@immutable
class FreeUpSpaceDeleteSummary {
  const FreeUpSpaceDeleteSummary({
    required this.requested,
    required this.deleted,
    required this.failed,
    required this.deletedBytes,
    required this.userCancelled,
  });

  final int requested;
  final int deleted;
  final int failed;
  final int deletedBytes;
  final bool userCancelled;
}

@immutable
class FreeUpSpaceState {
  const FreeUpSpaceState({
    this.scanning = false,
    this.deleting = false,
    this.permissionDenied = false,
    this.limitedAccess = false,
    this.userCancelledLastDelete = false,
    this.eligibleCount = 0,
    this.eligibleBytes = 0,
    this.photoCount = 0,
    this.videoCount = 0,
    this.photoBytes = 0,
    this.videoBytes = 0,
    this.scannedCount = 0,
    this.backendAllowedCount = 0,
    this.skippedNotBackedUp = 0,
    this.skippedManualUpload = 0,
    this.skippedRemoteMissing = 0,
    this.skippedAlreadyCleaned = 0,
    this.skippedCurrentlyUploading = 0,
    this.skippedUnsupportedUri = 0,
    this.skippedPathOnly = 0,
    this.lastScanAt,
    this.error,
    this.lastSuccessMessage,
    this.candidates = const [],
  });

  final bool scanning;
  final bool deleting;
  final bool permissionDenied;
  final bool limitedAccess;
  final bool userCancelledLastDelete;
  final int eligibleCount;
  final int eligibleBytes;
  final int photoCount;
  final int videoCount;
  final int photoBytes;
  final int videoBytes;
  final int scannedCount;
  final int backendAllowedCount;
  final int skippedNotBackedUp;
  final int skippedManualUpload;
  final int skippedRemoteMissing;
  final int skippedAlreadyCleaned;
  final int skippedCurrentlyUploading;
  final int skippedUnsupportedUri;
  final int skippedPathOnly;
  final DateTime? lastScanAt;
  final String? error;
  final String? lastSuccessMessage;
  final List<FreeUpSpaceCandidate> candidates;

  FreeUpSpaceState copyWith({
    bool? scanning,
    bool? deleting,
    bool? permissionDenied,
    bool? limitedAccess,
    bool? userCancelledLastDelete,
    int? eligibleCount,
    int? eligibleBytes,
    int? photoCount,
    int? videoCount,
    int? photoBytes,
    int? videoBytes,
    int? scannedCount,
    int? backendAllowedCount,
    int? skippedNotBackedUp,
    int? skippedManualUpload,
    int? skippedRemoteMissing,
    int? skippedAlreadyCleaned,
    int? skippedCurrentlyUploading,
    int? skippedUnsupportedUri,
    int? skippedPathOnly,
    DateTime? lastScanAt,
    String? error,
    bool clearError = false,
    String? lastSuccessMessage,
    bool clearLastSuccessMessage = false,
    List<FreeUpSpaceCandidate>? candidates,
  }) {
    return FreeUpSpaceState(
      scanning: scanning ?? this.scanning,
      deleting: deleting ?? this.deleting,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      limitedAccess: limitedAccess ?? this.limitedAccess,
      userCancelledLastDelete:
          userCancelledLastDelete ?? this.userCancelledLastDelete,
      eligibleCount: eligibleCount ?? this.eligibleCount,
      eligibleBytes: eligibleBytes ?? this.eligibleBytes,
      photoCount: photoCount ?? this.photoCount,
      videoCount: videoCount ?? this.videoCount,
      photoBytes: photoBytes ?? this.photoBytes,
      videoBytes: videoBytes ?? this.videoBytes,
      scannedCount: scannedCount ?? this.scannedCount,
      backendAllowedCount: backendAllowedCount ?? this.backendAllowedCount,
      skippedNotBackedUp: skippedNotBackedUp ?? this.skippedNotBackedUp,
      skippedManualUpload: skippedManualUpload ?? this.skippedManualUpload,
      skippedRemoteMissing: skippedRemoteMissing ?? this.skippedRemoteMissing,
      skippedAlreadyCleaned:
          skippedAlreadyCleaned ?? this.skippedAlreadyCleaned,
      skippedCurrentlyUploading:
          skippedCurrentlyUploading ?? this.skippedCurrentlyUploading,
      skippedUnsupportedUri:
          skippedUnsupportedUri ?? this.skippedUnsupportedUri,
      skippedPathOnly: skippedPathOnly ?? this.skippedPathOnly,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      error: clearError ? null : error ?? this.error,
      lastSuccessMessage: clearLastSuccessMessage
          ? null
          : lastSuccessMessage ?? this.lastSuccessMessage,
      candidates: candidates ?? this.candidates,
    );
  }
}

class FreeUpSpaceController extends ChangeNotifier {
  FreeUpSpaceController({
    required AuthController auth,
    required UploadController uploads,
    required DriveRepository drive,
    GalleryMediaScanner scanner = const GalleryMediaScanner(),
    GalleryBackupAssetStore assetStore = const GalleryBackupAssetStore(),
    bool Function() isAndroid = _defaultIsAndroid,
  }) : _auth = auth,
       _uploads = uploads,
       _drive = drive,
       _scanner = scanner,
       _assetStore = assetStore,
       _isAndroid = isAndroid;

  final AuthController _auth;
  final UploadController _uploads;
  final DriveRepository _drive;
  final GalleryMediaScanner _scanner;
  final GalleryBackupAssetStore _assetStore;
  final bool Function() _isAndroid;

  FreeUpSpaceState state = const FreeUpSpaceState();

  Future<void> scan() async {
    if (state.scanning || state.deleting) return;
    state = state.copyWith(
      scanning: true,
      userCancelledLastDelete: false,
      clearError: true,
      clearLastSuccessMessage: true,
    );
    notifyListeners();
    try {
      final next = await _buildScanState();
      state = next.copyWith(scanning: false);
    } catch (err) {
      state = FreeUpSpaceState(
        lastScanAt: DateTime.now(),
        error:
            'TeleDrive could not confirm which Auto Backup items are safely stored in the cloud. Nothing was deleted.',
      );
    }
    notifyListeners();
  }

  Future<FreeUpSpaceDeleteSummary> freeUpSpace() async {
    if (state.deleting || state.candidates.isEmpty) {
      return const FreeUpSpaceDeleteSummary(
        requested: 0,
        deleted: 0,
        failed: 0,
        deletedBytes: 0,
        userCancelled: false,
      );
    }
    state = state.copyWith(
      deleting: true,
      userCancelledLastDelete: false,
      clearError: true,
      clearLastSuccessMessage: true,
    );
    notifyListeners();

    var requested = 0;
    var deleted = 0;
    var failed = 0;
    var deletedBytes = 0;
    final scope = _assetScope();
    try {
      if (scope == null) {
        throw Exception('Sign in before freeing space.');
      }
      final verified = await _buildScanState();
      final candidates = verified.candidates;
      if (candidates.isEmpty) {
        state = verified.copyWith(deleting: false);
        notifyListeners();
        return const FreeUpSpaceDeleteSummary(
          requested: 0,
          deleted: 0,
          failed: 0,
          deletedBytes: 0,
          userCancelled: false,
        );
      }

      const chunkSize = 200;
      final byUri = {
        for (final candidate in candidates) candidate.contentUri: candidate,
      };
      for (var start = 0; start < candidates.length; start += chunkSize) {
        final chunk = candidates.skip(start).take(chunkSize).toList();
        final result = await _scanner.deleteMediaUris(
          chunk.map((candidate) => candidate.contentUri).toList(),
        );
        requested += result.requested;
        if (result.userCancelled) {
          state = verified.copyWith(
            deleting: false,
            userCancelledLastDelete: true,
            lastSuccessMessage: 'Nothing was deleted.',
          );
          notifyListeners();
          return FreeUpSpaceDeleteSummary(
            requested: requested,
            deleted: deleted,
            failed: failed + result.failed,
            deletedBytes: deletedBytes,
            userCancelled: true,
          );
        }

        final deletedFingerprints = <String>[];
        for (final uri in result.deletedUris) {
          final candidate = byUri[uri];
          if (candidate == null) continue;
          deleted++;
          deletedBytes += candidate.sizeBytes;
          deletedFingerprints.add(candidate.fingerprint);
        }
        if (deletedFingerprints.isNotEmpty) {
          await _assetStore.markCleaned(scope, deletedFingerprints);
        }

        for (final uri in result.failedUris) {
          final candidate = byUri[uri];
          if (candidate == null) continue;
          failed++;
          await _assetStore.markCleanupFailed(
            scope,
            candidate.fingerprint,
            failureCode: 'android_delete_failed',
            failureMessage: 'Android could not remove this local media item.',
          );
        }
      }

      final refreshed = await _buildScanState();
      final message = failed > 0
          ? 'Freed $deleted items. $failed could not be removed.'
          : deletedBytes > 0
          ? 'Freed up ${_formatBytes(deletedBytes)} from this device.'
          : null;
      state = refreshed.copyWith(
        deleting: false,
        lastSuccessMessage: message,
        userCancelledLastDelete: false,
      );
      notifyListeners();
      return FreeUpSpaceDeleteSummary(
        requested: requested,
        deleted: deleted,
        failed: failed,
        deletedBytes: deletedBytes,
        userCancelled: false,
      );
    } catch (err) {
      state = FreeUpSpaceState(
        lastScanAt: DateTime.now(),
        error:
            'TeleDrive could not confirm which Auto Backup items are safely stored in the cloud. Nothing was deleted.',
      );
      notifyListeners();
      return FreeUpSpaceDeleteSummary(
        requested: requested,
        deleted: deleted,
        failed: failed,
        deletedBytes: deletedBytes,
        userCancelled: false,
      );
    }
  }

  void clearTransientMessages() {
    state = state.copyWith(clearError: true, clearLastSuccessMessage: true);
    notifyListeners();
  }

  Future<FreeUpSpaceState> _buildScanState() async {
    final scope = _assetScope();
    if (scope == null || !_auth.isAuthenticated) {
      return const FreeUpSpaceState(
        error: 'Sign in before freeing space on this device.',
      );
    }
    if (!_isAndroid()) {
      return FreeUpSpaceState(lastScanAt: DateTime.now());
    }

    final permissions = await _mediaPermissions();
    if (!permissions.images && !permissions.videos) {
      return FreeUpSpaceState(
        permissionDenied: true,
        limitedAccess: permissions.limited,
        lastScanAt: DateTime.now(),
      );
    }

    final scan = await _scanner.scanRecent(
      limit: 1000,
      includeImages: permissions.images,
      includeVideos: permissions.videos,
      strategy: 'media_store_only',
    );
    final localRecords = await _assetStore.load(scope);
    final activeFingerprints = _uploads.activeGalleryBackupFingerprints;

    var skippedPathOnly = 0;
    var skippedUnsupportedUri = scan.invalidSkipCount;
    var skippedAlreadyCleaned = 0;
    var skippedCurrentlyUploading = 0;
    final backendInput = <GalleryMediaAsset>[];

    for (final asset in scan.assets) {
      if (asset.sourceKind != 'mediastore') {
        skippedPathOnly++;
        continue;
      }
      if (!_isConcreteMediaStoreContentUri(asset.contentUri)) {
        skippedUnsupportedUri++;
        continue;
      }
      if (asset.sizeBytes <= 0 ||
          (asset.mediaType != 'image' && asset.mediaType != 'video')) {
        skippedUnsupportedUri++;
        continue;
      }
      final local = localRecords[asset.fingerprint];
      if (local?.isCleaned == true) {
        skippedAlreadyCleaned++;
        continue;
      }
      if (activeFingerprints.contains(asset.fingerprint)) {
        skippedCurrentlyUploading++;
        continue;
      }
      backendInput.add(asset);
    }

    final decisions = backendInput.isEmpty
        ? <String, FreeUpSpaceResolveDecision>{}
        : await _drive.resolveFreeUpSpaceCandidates(backendInput);

    var skippedNotBackedUp = 0;
    var skippedManualUpload = 0;
    var skippedRemoteMissing = 0;
    var backendAllowedCount = 0;
    var eligibleBytes = 0;
    var photoCount = 0;
    var videoCount = 0;
    var photoBytes = 0;
    var videoBytes = 0;
    final candidates = <FreeUpSpaceCandidate>[];

    for (final asset in backendInput) {
      final decision = decisions[asset.fingerprint];
      if (_isAllowedDecision(decision)) {
        backendAllowedCount++;
        eligibleBytes += asset.sizeBytes;
        if (asset.mediaType == 'video') {
          videoCount++;
          videoBytes += asset.sizeBytes;
        } else {
          photoCount++;
          photoBytes += asset.sizeBytes;
        }
        candidates.add(
          FreeUpSpaceCandidate(
            fingerprint: asset.fingerprint,
            contentUri: asset.contentUri,
            name: asset.name,
            sizeBytes: asset.sizeBytes,
            mediaType: asset.mediaType,
            mimeType: asset.mimeType,
            modifiedAtMillis: asset.modifiedAtMillis,
            addedAtMillis: asset.addedAtMillis,
            relativePath: asset.relativePath,
            thumbnailHintPath: asset.path,
            backendReason: decision!.reason,
          ),
        );
        await _assetStore.markUploadedAsset(scope, asset);
        continue;
      }
      switch (decision?.reason) {
        case 'manual_upload':
          skippedManualUpload++;
          break;
        case 'remote_missing':
        case 'remote_deleted':
        case 'remote_trashed':
        case 'remote_unavailable':
          skippedRemoteMissing++;
          break;
        default:
          skippedNotBackedUp++;
      }
    }

    return FreeUpSpaceState(
      permissionDenied: false,
      limitedAccess: permissions.limited,
      eligibleCount: candidates.length,
      eligibleBytes: eligibleBytes,
      photoCount: photoCount,
      videoCount: videoCount,
      photoBytes: photoBytes,
      videoBytes: videoBytes,
      scannedCount: scan.assets.length,
      backendAllowedCount: backendAllowedCount,
      skippedNotBackedUp: skippedNotBackedUp,
      skippedManualUpload: skippedManualUpload,
      skippedRemoteMissing: skippedRemoteMissing,
      skippedAlreadyCleaned: skippedAlreadyCleaned,
      skippedCurrentlyUploading: skippedCurrentlyUploading,
      skippedUnsupportedUri: skippedUnsupportedUri,
      skippedPathOnly: skippedPathOnly,
      lastScanAt: DateTime.now(),
      candidates: candidates,
    );
  }

  Future<({bool images, bool videos, bool limited})> _mediaPermissions() async {
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    var imagesGranted = photos.isGranted || photos.isLimited;
    var videosGranted = videos.isGranted || videos.isLimited;
    var limited = photos.isLimited || videos.isLimited;
    if (!imagesGranted && !videosGranted) {
      final storage = await Permission.storage.request();
      if (storage.isGranted || storage.isLimited) {
        imagesGranted = true;
        videosGranted = true;
        limited = storage.isLimited;
      }
    }
    return (images: imagesGranted, videos: videosGranted, limited: limited);
  }

  bool _isAllowedDecision(FreeUpSpaceResolveDecision? decision) {
    return decision != null &&
        decision.cleanupAllowed &&
        decision.clientSource == 'gallery_backup' &&
        (decision.backupSource == null ||
            decision.backupSource == 'gallery_backup') &&
        decision.remoteAvailable;
  }

  String? _assetScope() {
    final userId = _auth.user?.userId;
    final telegramId =
        _auth.user?.telegramId ?? _auth.activeAccount?.telegramId ?? 0;
    if (userId == null || telegramId == 0) return null;
    return '${userId}_$telegramId';
  }

  static bool _isConcreteMediaStoreContentUri(String value) {
    if (!value.startsWith('content://media/')) return false;
    if (!value.contains('/images/media/') && !value.contains('/video/media/')) {
      return false;
    }
    return int.tryParse(value.split('/').last) != null;
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  static bool _defaultIsAndroid() => Platform.isAndroid;
}
