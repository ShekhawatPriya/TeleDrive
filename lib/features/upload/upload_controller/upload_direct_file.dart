part of '../upload_controller.dart';

extension _UploadDirectFile on UploadController {
  Future<void> _uploadDirectFiles({
    required List<UploadItem> batchItems,
    required List<Map<String, dynamic>> files,
    required TelegramUploadTarget? preparedTarget,
    required int batchId,
    required int backendUserId,
    required int telegramUserId,
  }) async {
    for (final item in batchItems) {
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
        final scope = _backupScope();
        if (scope != null && latest.backupFingerprint != null) {
          await _backupAssetStore.mark(
            scope,
            latest.backupFingerprint!,
            GalleryBackupAssetStatus.uploading,
          );
        }
        final result = await _telegram.uploadOriginal(
          filePath: latest.path,
          filename: latest.name,
          mimeType: latest.mimeType,
          sizeBytes: latest.size,
          target: target,
          transferId: transferId,
        );
        uploadedToTelegram = true;
        final derivativePayloads = await _uploadDirectDerivatives(
          item: latest,
          intent: intent,
          target: target,
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
          thumbnailReady: true,
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
