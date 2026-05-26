part of 'gallery_backup_controller.dart';

extension _GalleryBackupScan on GalleryBackupController {
  Future<void> _scanNow({
    String reason = 'manual',
    bool bypassThrottle = true,
    bool scheduleDelayedRescan = true,
  }) async {
    if (_running) return;
    if (!bypassThrottle && diagnostics.lastScanStartedAt != null) {
      final elapsed = DateTime.now().difference(diagnostics.lastScanStartedAt!);
      if (elapsed < GalleryBackupController._resumeScanThrottle) return;
    }
    if (!await _canScan()) return;

    final started = DateTime.now();
    final settings = _settings.state;
    final notes = <String>[
      if (settings.galleryBackupIndexingStrategy !=
          GalleryBackupIndexingStrategy.mediaStoreOnly)
        'File path scanning is limited to accessible public media directories by Android scoped storage.',
      if (reason == 'resume')
        'Resume scans are throttled and followed by a delayed rescan.',
    ];
    _running = true;
    diagnostics = diagnostics.copyWith(
      lastScanStartedAt: started,
      indexingStrategy: settings.galleryBackupIndexingStrategy,
      scanLimit: settings.galleryBackupScanLimit,
      queueLimit: settings.galleryBackupQueueLimit,
      mediaStoreItemsScanned: 0,
      pathItemsScanned: 0,
      mergedCandidates: 0,
      skippedAlreadyUploaded: 0,
      skippedAlreadyQueued: 0,
      skippedPermission: 0,
      skippedInvalid: 0,
      enqueued: 0,
      notes: notes,
      clearLastError: true,
      clearLastEnqueueError: true,
    );
    _emitChange();

    var skippedUploaded = 0;
    var skippedQueued = 0;
    var skippedInvalid = 0;
    var enqueued = 0;
    String? enqueueError;
    try {
      final permissions = await _mediaPermissions();
      if (!permissions.images && !permissions.videos) {
        diagnostics = diagnostics.copyWith(skippedPermission: 1);
        return;
      }

      final scan = await _scanner.scanRecent(
        limit: settings.galleryBackupScanLimit,
        includeImages: permissions.images,
        includeVideos: permissions.videos,
        strategy: settings.galleryBackupIndexingStrategy.storageValue,
      );
      final scope = _assetScope();
      if (scope == null) return;

      final localRecords = await _assetStore.load(scope);
      final activeFingerprints = _uploads.activeGalleryBackupFingerprints;
      final localUploadedAt = _lastUploadedAt(localRecords);
      final eligible = <GalleryMediaAsset>[];

      for (final asset in scan.assets) {
        final local = localRecords[asset.fingerprint];
        if (local?.isUploaded == true) {
          skippedUploaded++;
          continue;
        }
        if (activeFingerprints.contains(asset.fingerprint) ||
            local?.status == GalleryBackupAssetStatus.queued ||
            local?.status == GalleryBackupAssetStatus.uploading) {
          skippedQueued++;
          continue;
        }
        eligible.add(asset);
      }

      final capacity =
          settings.galleryBackupQueueLimit -
          _uploads.activeGalleryBackupQueueCount;
      if (capacity <= 0 || eligible.isEmpty) {
        diagnostics = diagnostics.copyWith(
          mediaStoreItemsScanned: scan.mediaStoreCount,
          pathItemsScanned: scan.pathCount,
          mergedCandidates: scan.mergedCount,
          skippedInvalid: scan.invalidSkipCount,
          skippedAlreadyUploaded: skippedUploaded,
          skippedAlreadyQueued: skippedQueued,
          lastUploadCompleteMarker: localUploadedAt,
          notes: [...notes, ...scan.diagnostics],
        );
        return;
      }

      await _assetStore.markMany(
        scope,
        eligible.map((asset) => asset.fingerprint),
        GalleryBackupAssetStatus.discovered,
      );
      final resolved = await _resolveBackupAssets(eligible);
      final candidates = <GalleryMediaAsset>[];
      for (final asset in eligible) {
        final decision = resolved[asset.fingerprint];
        if (decision == _BackupResolveDecision.uploaded) {
          skippedUploaded++;
          await _assetStore.markUploadedAsset(scope, asset);
          continue;
        }
        if (decision == _BackupResolveDecision.queued) {
          skippedQueued++;
          continue;
        }
        candidates.add(asset);
        if (candidates.length >= capacity) break;
      }

      final items = <UploadItem>[];
      for (final asset in candidates) {
        if (!_settings.state.galleryBackupEnabled) break;
        try {
          final folderId = await _destinationFolderId(asset);
          final local = await _scanner.localPathFor(asset);
          items.add(
            UploadItem(
              localId: GalleryBackupController._uuid.v4(),
              uploadClientId: GalleryBackupController._uuid.v4(),
              name: asset.name,
              size: asset.sizeBytes,
              mimeType: asset.mimeType,
              path: local.path,
              status: UploadStatus.selected,
              clientSource: 'gallery_backup',
              destinationFolderId: folderId,
              backupFingerprint: asset.fingerprint,
              backupSourceKind: asset.sourceKind,
              contentUri: asset.contentUri,
              deleteLocalOnComplete: local.deleteWhenDone,
              localModifiedAt: asset.recencyMillis > 0
                  ? DateTime.fromMillisecondsSinceEpoch(asset.recencyMillis)
                  : null,
              addedAtMillis: asset.addedAtMillis,
              mediaType: asset.mediaType,
              relativePath: asset.relativePath,
              durationMs: asset.durationMs,
            ),
          );
        } catch (err) {
          skippedInvalid++;
          enqueueError = '$err';
          debugPrint('Gallery backup skipped ${asset.contentUri}: $err');
          await _assetStore.mark(
            scope,
            asset.fingerprint,
            GalleryBackupAssetStatus.failed,
            failureCode: 'candidate_prepare_failed',
            failureMessage: '$err',
          );
        }
      }

      if (items.isNotEmpty && _settings.state.galleryBackupEnabled) {
        try {
          await _assetStore.markMany(
            scope,
            items.map((item) => item.backupFingerprint).whereType<String>(),
            GalleryBackupAssetStatus.queued,
          );
          await _uploads.enqueueGalleryBackupItems(items);
          enqueued = items.length;
        } catch (err) {
          enqueueError = '$err';
          await _assetStore.markMany(
            scope,
            items.map((item) => item.backupFingerprint).whereType<String>(),
            GalleryBackupAssetStatus.failed,
            failureCode: 'enqueue_failed',
            failureMessage: '$err',
          );
        }
      }

      diagnostics = diagnostics.copyWith(
        mediaStoreItemsScanned: scan.mediaStoreCount,
        pathItemsScanned: scan.pathCount,
        mergedCandidates: scan.mergedCount,
        skippedInvalid: scan.invalidSkipCount + skippedInvalid,
        skippedAlreadyUploaded: skippedUploaded,
        skippedAlreadyQueued: skippedQueued,
        enqueued: enqueued,
        lastEnqueueError: enqueueError,
        lastUploadCompleteMarker: localUploadedAt,
        notes: [...notes, ...scan.diagnostics],
      );
    } catch (err) {
      diagnostics = diagnostics.copyWith(lastError: '$err');
      debugPrint('Gallery backup scan failed: $err');
    } finally {
      final completed = DateTime.now();
      diagnostics = diagnostics.copyWith(
        lastScanCompletedAt: completed,
        scanDuration: completed.difference(started),
      );
      _running = false;
      _emitChange();
      if (scheduleDelayedRescan && _settings.state.galleryBackupEnabled) {
        _scheduleDelayedRescan();
      }
    }
  }
}
