part of 'gallery_backup_controller.dart';

extension _GalleryBackupControllerHelpers on GalleryBackupController {
  Future<bool> _canScan() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (!_settings.state.loaded || !_settings.state.galleryBackupEnabled) {
      return false;
    }
    if (!_auth.galleryBackupEnabled ||
        !_auth.directTelegramUploadEnabled ||
        _auth.telegramConnected != true ||
        !_auth.isAuthenticated) {
      return false;
    }
    if (_settings.state.galleryBackupWifiOnly) {
      final connectivity = await Connectivity().checkConnectivity();
      final hasWifi =
          connectivity.contains(ConnectivityResult.wifi) ||
          connectivity.contains(ConnectivityResult.ethernet);
      if (!hasWifi) return false;
    }
    return true;
  }

  Future<({bool images, bool videos})> _mediaPermissions() async {
    if (Platform.isIOS) {
      // One photo-library permission covers photos and videos on iOS.
      // Permission.videos has no iOS strategy (reports permanently denied) and
      // Permission.storage is always granted there, which would mask denial.
      final photos = await Permission.photos.request();
      final granted = photos.isGranted || photos.isLimited;
      return (images: granted, videos: granted);
    }
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    var imagesGranted = photos.isGranted || photos.isLimited;
    var videosGranted = videos.isGranted || videos.isLimited;
    if (!imagesGranted && !videosGranted) {
      final storage = await Permission.storage.request();
      if (storage.isGranted || storage.isLimited) {
        imagesGranted = true;
        videosGranted = true;
      }
    }
    return (images: imagesGranted, videos: videosGranted);
  }

  Future<Map<String, _BackupResolveDecision>> _resolveBackupAssets(
    List<GalleryMediaAsset> assets,
  ) async {
    final res = await _drive.api.dio.post(
      '/client-backup-assets/resolve',
      data: {
        'assets': assets
            .map(
              (asset) => {
                'source_kind': asset.sourceKind,
                'client_source': 'gallery_backup',
                'backup_source': 'gallery_backup',
                'media_type': asset.mediaType,
                'mime_type': asset.mimeType,
                'fingerprint': asset.fingerprint,
                'content_uri': asset.contentUri,
                'relative_path': asset.relativePath,
                'display_name': asset.name,
                'size_bytes': asset.sizeBytes,
                'modified_at_millis': asset.modifiedAtMillis,
                'added_at_millis': asset.addedAtMillis,
                'duration_ms': asset.durationMs,
                'status': 'discovered',
              },
            )
            .toList(),
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final rawRows = data['assets'] is List ? data['assets'] : data['items'];
    final rows = (rawRows is List ? rawRows : const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return {
      for (final row in rows)
        '${row['fingerprint']}': _decisionFromResolve(row),
    };
  }

  _BackupResolveDecision _decisionFromResolve(Map<String, dynamic> row) {
    final status = '${row['status'] ?? ''}';
    final decision = '${row['decision'] ?? ''}';
    if (status == 'uploaded' ||
        decision == 'already_uploaded' ||
        row['uploaded'] == true) {
      return _BackupResolveDecision.uploaded;
    }
    if (status == 'queued' ||
        status == 'uploading' ||
        decision == 'already_queued') {
      return _BackupResolveDecision.queued;
    }
    if (row['shouldUpload'] == false || row['should_upload'] == false) {
      return _BackupResolveDecision.queued;
    }
    return _BackupResolveDecision.upload;
  }

  Future<String?> _destinationFolderId(GalleryMediaAsset asset) async {
    final path = _destinationPath(asset);
    final cacheKey = path.join('/');
    final cached = _folderIdCache[cacheKey];
    if (cached != null) return cached;
    final folder = await _drive.ensureFolderPath(path);
    _folderIdCache[cacheKey] = folder.id;
    return folder.id;
  }

  List<String> _destinationPath(GalleryMediaAsset asset) {
    if (asset.mediaType == 'video' || asset.mimeType.startsWith('video/')) {
      return const ['Auto', 'Media', 'Videos'];
    }
    if (asset.mediaType == 'image' || asset.mimeType.startsWith('image/')) {
      return const ['Auto', 'Media', 'Photos'];
    }
    return const ['Auto', 'Media'];
  }

  DateTime? _lastUploadedAt(Map<String, GalleryBackupAssetRecord> records) {
    DateTime? latest;
    for (final record in records.values) {
      if (!record.isUploaded) continue;
      if (latest == null || record.updatedAt.isAfter(latest)) {
        latest = record.updatedAt;
      }
    }
    return latest;
  }

  String? _assetScope() {
    final userId = _auth.user?.userId;
    final telegramId =
        _auth.user?.telegramId ?? _auth.activeAccount?.telegramId ?? 0;
    if (userId == null || telegramId == 0) return null;
    return '${userId}_$telegramId';
  }
}

enum _BackupResolveDecision { upload, uploaded, queued }
