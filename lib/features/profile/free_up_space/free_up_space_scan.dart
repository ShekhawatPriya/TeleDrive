part of 'free_up_space_controller.dart';

extension _FreeUpSpaceScan on FreeUpSpaceController {
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

  bool _isConcreteMediaStoreContentUri(String value) {
    if (!value.startsWith('content://media/')) return false;
    if (!value.contains('/images/media/') && !value.contains('/video/media/')) {
      return false;
    }
    return int.tryParse(value.split('/').last) != null;
  }

  String _formatBytes(int bytes) {
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
}

bool _defaultIsAndroid() => Platform.isAndroid;
