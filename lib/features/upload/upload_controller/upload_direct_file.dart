part of '../upload_controller.dart';

extension _UploadDirectFile on UploadController {
  /// Mirrors TDLib's uploaded bytes into the row and a smoothed speed. The
  /// subscription must exist before the native send starts: the bridge drops
  /// events for transfers nobody observes, which left the bar at its floor.
  StreamSubscription<TelegramTransferProgress>? _trackOriginalProgress(
    UploadItem item,
    String transferId,
  ) {
    final clock = Stopwatch()..start();
    var sampleMs = 0;
    var sampleBytes = 0;
    double? speed;
    try {
      return _telegram.watchProgress(transferId).listen((event) {
        if (event.state != TelegramTransferState.uploading) return;
        final current = _findItem(item.localId);
        if (current == null ||
            current.uploadClientId != item.uploadClientId ||
            current.cancelRequested ||
            current.status != UploadStatus.uploadingOriginalToTelegram) {
          return;
        }
        final total = (event.totalBytes ?? 0) > 0
            ? event.totalBytes!
            : item.size;
        if (total <= 0) return;
        final fraction = (event.bytesDone / total).clamp(0.0, 1.0);
        final now = clock.elapsedMilliseconds;
        final elapsed = now - sampleMs;
        if (elapsed >= 500 && event.bytesDone >= sampleBytes) {
          final instant = (event.bytesDone - sampleBytes) * 1000 / elapsed;
          // Exponential smoothing keeps the rate readable on bursty links.
          speed = sampleMs == 0 && sampleBytes == 0
              ? null
              : speed == null
              ? instant
              : speed! * .7 + instant * .3;
          sampleMs = now;
          sampleBytes = event.bytesDone;
        }
        // TDLib can restart a part after a reconnect; never move backwards.
        if (fraction <= current.serverProgress &&
            speed == current.bytesPerSecond) {
          return;
        }
        _setItem(
          item.localId,
          serverProgress: fraction > current.serverProgress
              ? fraction
              : current.serverProgress,
          bytesPerSecond: speed,
        );
      });
    } catch (err) {
      debugPrint('Upload progress unavailable for ${item.name}: $err');
      return null;
    }
  }

  Future<void> _uploadDirectFiles({
    required List<UploadItem> batchItems,
    required List<Map<String, dynamic>> files,
    required TelegramUploadTarget? preparedTarget,
    required int batchId,
    required int backendUserId,
    required int telegramUserId,
  }) async {
    for (final item in batchItems) {
      if (!_isCurrentUpload(item)) continue;
      final latest = _findItem(item.localId);
      if (latest == null || latest.cancelRequested) continue;
      final intent = files
          .where((f) => f['localId'] == latest.localId)
          .firstOrNull;
      if (intent == null) {
        _setItem(
          latest.localId,
          status: UploadStatus.failed,
          error: 'Backend did not return an upload intent for this file.',
        );
        continue;
      }
      final intentStatus = '${intent['status'] ?? ''}';
      final duplicateResolution =
          '${intent['duplicateResolution'] ?? intent['duplicate_resolution'] ?? ''}';
      if (intentStatus == 'completed' ||
          duplicateResolution == 'already_uploaded') {
        _setItem(
          latest.localId,
          status: UploadStatus.uploaded,
          serverProgress: 1,
          thumbnailReady: true,
        );
        final backupScope = _backupScope();
        if (backupScope != null &&
            latest.clientSource == 'gallery_backup' &&
            latest.backupFingerprint != null) {
          await _backupAssetStore.markUploadedUploadItem(backupScope, latest);
        }
        continue;
      }
      final fileId = (intent['fileId'] as num).toInt();
      final target = intent['telegramTarget'] is Map
          ? TelegramUploadTarget.fromJson(
              Map<String, dynamic>.from(intent['telegramTarget'] as Map),
            )
          : preparedTarget;
      if (target == null) {
        throw const TelegramClientUnavailableException(
          'Backend did not return a Telegram upload target.',
          code: 'tdlib_target_unresolved',
        );
      }
      final transferId = latest.uploadClientId;
      var uploadedToTelegram = false;
      try {
        _setItem(
          latest.localId,
          status: UploadStatus.uploadingOriginalToTelegram,
          serverProgress: 0,
        );
        await _api.dio.post(
          '/client-uploads/$batchId/file-started',
          data: {
            'file_id': fileId,
            'local_id': latest.localId,
            'transfer_id': transferId,
            'estimated_total_bytes': latest.size,
          },
        );
        if (!_isCurrentUpload(latest)) continue;
        final scope = _backupScope();
        if (scope != null && latest.backupFingerprint != null) {
          await _backupAssetStore.mark(
            scope,
            latest.backupFingerprint!,
            GalleryBackupAssetStatus.uploading,
          );
        }
        if (!_isCurrentUpload(latest)) continue;
        final progress = _trackOriginalProgress(latest, transferId);
        final TelegramUploadResult result;
        try {
          result = await _telegram.uploadOriginal(
            filePath: latest.path,
            filename: latest.name,
            mimeType: latest.mimeType,
            sizeBytes: latest.size,
            target: target,
            transferId: transferId,
          );
        } finally {
          await progress?.cancel();
        }
        uploadedToTelegram = true;
        final derivativePayloads = await _uploadDirectDerivatives(
          item: latest,
          intent: intent,
          target: target,
        );
        final thumbnailReady = directDerivativePayloadsReady(
          latest,
          derivativePayloads,
        );
        final commitPath = '/client-uploads/$batchId/file-complete';
        final commitPayload = {
          'file_id': fileId,
          'local_id': latest.localId,
          'original': result.ref.toCommitJson(
            filename: latest.name,
            mimeType: latest.mimeType,
            sizeBytes: latest.size,
          ),
          ...derivativePayloads,
          'app_version': 'flutter',
          'platform': Platform.operatingSystem,
          'upload_strategy': 'tdlib',
        };
        final commitScope = _pendingCommits.activeScope(
          backendUserId: backendUserId,
          telegramUserId: telegramUserId,
        );
        final commitId = '$batchId:$fileId:${latest.localId}';
        await _pendingCommits.save(
          commitScope,
          PendingTelegramCommit(
            id: commitId,
            backendBaseUrlHash: _pendingCommits.backendBaseUrlHash,
            backendUserId: backendUserId,
            telegramUserId: telegramUserId,
            batchId: batchId,
            fileId: fileId,
            localId: latest.localId,
            filename: latest.name,
            mimeType: latest.mimeType,
            sizeBytes: latest.size,
            path: commitPath,
            payload: commitPayload,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        unawaited(_auth.refreshPendingDirectCommitCount());
        final commitDelaySeconds = AppConfig.tdlibE2eCommitDelaySeconds;
        if (commitDelaySeconds > 0) {
          debugPrint(
            'TDLIB_E2E_PENDING_COMMIT_SAVED id=$commitId '
            'delaySeconds=$commitDelaySeconds',
          );
          await Future<void>.delayed(Duration(seconds: commitDelaySeconds));
        }
        _setItem(
          latest.localId,
          status: UploadStatus.committingMetadata,
          serverProgress: 1,
        );
        await _commitClientUploadWithRetry(commitPath, commitPayload);
        await _pendingCommits.remove(commitScope, commitId);
        unawaited(_auth.refreshPendingDirectCommitCount());
        _setItem(
          latest.localId,
          status: UploadStatus.uploaded,
          serverProgress: 1,
          thumbnailReady: thumbnailReady,
        );
        // The server now has one more available file: reflect it instantly in
        // the destination folder's (and all its ancestors') displayed totals.
        _drive.bumpFolderAggregates(
          _destinationOf(latest),
          fileCountDelta: 1,
          sizeDelta: latest.size,
        );
        final backupScope = _backupScope();
        if (backupScope != null &&
            latest.clientSource == 'gallery_backup' &&
            latest.backupFingerprint != null) {
          await _backupAssetStore.markUploadedUploadItem(backupScope, latest);
        }
        if (latest.deleteLocalOnComplete) {
          unawaited(_safeDeleteLocalFile(latest.path));
        }
      } catch (err) {
        // Public cancellation owns this terminal state. In particular, a late
        // file-started response must not turn a cancelled item into a failure.
        if (!uploadedToTelegram && !_isCurrentUpload(latest)) continue;
        await _api.dio
            .post(
              '/client-uploads/$batchId/file-failed',
              data: {
                'file_id': fileId,
                'local_id': latest.localId,
                'failure_code': err is TelegramClientException
                    ? err.code ?? 'telegram_transfer_failed'
                    : uploadedToTelegram
                    ? 'metadata_commit_failed'
                    : 'telegram_transfer_failed',
                'failure_message': err.toString(),
                'retryable': true,
                'failed_stage': uploadedToTelegram
                    ? 'metadata_commit'
                    : 'telegram_upload_original',
              },
            )
            .catchError((_) => Response(requestOptions: RequestOptions()));
        _setItem(
          latest.localId,
          status: UploadStatus.failed,
          error: uploadedToTelegram
              ? _api.errorMessage(
                  err,
                  'Upload reached Telegram. Metadata commit will retry.',
                )
              : _api.errorMessage(err, 'Upload failed.'),
        );
        final scope = _backupScope();
        if (scope != null && latest.backupFingerprint != null) {
          await _backupAssetStore.mark(
            scope,
            latest.backupFingerprint!,
            GalleryBackupAssetStatus.failed,
            failureCode: err is TelegramClientException
                ? err.code ?? 'telegram_transfer_failed'
                : uploadedToTelegram
                ? 'metadata_commit_failed'
                : 'telegram_transfer_failed',
            failureMessage: err.toString(),
          );
        }
      }
    }
  }
}
