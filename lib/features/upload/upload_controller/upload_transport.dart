part of '../upload_controller.dart';

extension _UploadTransport on UploadController {
  void _pumpQueue() {
    final configuredConcurrency = AppConfig.maxConcurrentTelegramUploads;
    final concurrentLimit = configuredConcurrency < 1
        ? 1
        : configuredConcurrency > 2
        ? 2
        : configuredConcurrency;
    final availableSlots = concurrentLimit - _runningLocalIds.length;
    if (availableSlots <= 0) return;
    final firstQueued = items
        .where((i) => i.status == UploadStatus.queued)
        .firstOrNull;
    final nextFolderId = firstQueued?.destinationFolderId ?? activeFolderId;
    final next = items
        .where((i) => i.status == UploadStatus.queued)
        .where((i) => (i.destinationFolderId ?? activeFolderId) == nextFolderId)
        .take(availableSlots)
        .toList();
    if (next.isEmpty) {
      _updateUploadingFlag();
      _notifyListeners();
      return;
    }
    for (final item in next) {
      _runningLocalIds.add(item.localId);
    }
    unawaited(_uploadMany(next));
    _updateUploadingFlag();
    _notifyListeners();
  }

  Future<void> _uploadMany(List<UploadItem> batchItems) async {
    try {
      await _requireDirectUploadReady();
      await _uploadManyDirect(batchItems);
    } on TelegramClientException catch (err) {
      await _failBatchBeforeUpload(
        batchItems,
        _tdlibRequiredMessage(err.message),
        failureCode: err.code ?? 'tdlib_unavailable',
      );
    } catch (err) {
      await _failBatchBeforeUpload(
        batchItems,
        _tdlibRequiredMessage('$err'),
        failureCode: 'tdlib_unavailable',
      );
    }
  }

  Future<void> _requireDirectUploadReady() async {
    if (!_auth.directTelegramUploadEnabled) {
      throw const TelegramClientUnavailableException(
        'Local TDLib upload is not enabled by this backend.',
        code: 'tdlib_direct_upload_disabled',
      );
    }
    final user = _auth.user;
    if (user == null || user.telegramId == 0) {
      throw const TelegramClientUnavailableException(
        'Connect Telegram before uploading.',
        code: 'tdlib_not_connected',
      );
    }
    if (!await _telegram.isAvailable) {
      throw const TelegramClientUnavailableException(
        'TeleDrive requires a supported 64-bit Android device for local TDLib file transfer.',
        code: 'tdlib_unavailable',
      );
    }
    try {
      await _telegram.configure(
        backendUserId: '${user.userId}',
        telegramUserId: user.telegramId,
      );
      if (!await _telegram.isAuthorized) {
        throw const TelegramClientUnavailableException(
          'Local TDLib is not authorized.',
          code: 'tdlib_auth_required',
        );
      }
      final me = await _telegram.getMe();
      final tdlibUserId = _intish(me['id']);
      if (tdlibUserId != null && tdlibUserId != user.telegramId) {
        throw const TelegramAccountMismatchException(
          'Local TDLib account does not match the active TeleDrive account.',
          code: 'tdlib_account_mismatch',
        );
      }
    } on TelegramClientException {
      rethrow;
    }
  }

  Future<void> _failBatchBeforeUpload(
    List<UploadItem> batchItems,
    String message, {
    required String failureCode,
  }) async {
    final scope = _backupScope();
    for (final item in batchItems) {
      _setItem(
        item.localId,
        status: UploadStatus.failed,
        error: message,
        notify: false,
      );
      _runningLocalIds.remove(item.localId);
      if (scope != null && item.backupFingerprint != null) {
        await _backupAssetStore.mark(
          scope,
          item.backupFingerprint!,
          GalleryBackupAssetStatus.failed,
          failureCode: failureCode,
          failureMessage: message,
        );
      }
    }
    _flushSetItemBatch(force: true);
    await _refreshIfSettled();
    _pumpQueue();
  }

  String _tdlibRequiredMessage(String detail) {
    final trimmed = detail.trim();
    final suffix = trimmed.isEmpty ? '' : ' $trimmed';
    return 'TeleDrive uses local TDLib for file transfer. Reconnect Telegram on this device to continue.$suffix';
  }

  Future<void> _uploadManyDirect(List<UploadItem> batchItems) async {
    if (await _isBlockedOnMobileData()) {
      for (final item in batchItems) {
        _runningLocalIds.remove(item.localId);
        _setItem(item.localId, status: UploadStatus.waitingForWifi);
      }
      _updateUploadingFlag();
      _notifyListeners();
      return;
    }
    final user = _auth.user;
    if (user == null || user.telegramId == 0) {
      throw const TelegramClientUnavailableException(
        'Connect Telegram before direct upload.',
        code: 'tdlib_not_connected',
      );
    }
    await _telegram.configure(
      backendUserId: '${user.userId}',
      telegramUserId: user.telegramId,
    );
    if (!await _telegram.isAuthorized) {
      throw const TelegramClientUnavailableException(
        'Local TDLib is not authorized.',
        code: 'tdlib_auth_required',
      );
    }
    for (final item in batchItems) {
      _setItem(
        item.localId,
        status: UploadStatus.preparingMetadata,
        httpProgress: 0,
        serverProgress: 0,
        clearError: true,
        notify: false,
      );
    }
    _flushSetItemBatch();

    try {
      TelegramUploadTarget? preparedTarget;
      final effectiveFolderId =
          batchItems.first.destinationFolderId ?? activeFolderId;
      final prepareRes = await _api.dio.post(
        '/client-uploads/prepare-target',
        data: {
          'folder_id': effectiveFolderId == null
              ? null
              : int.parse(effectiveFolderId),
        },
      );
      final prepareData = Map<String, dynamic>.from(prepareRes.data as Map);
      if (prepareData['telegramTarget'] is Map) {
        preparedTarget = TelegramUploadTarget.fromJson(
          Map<String, dynamic>.from(prepareData['telegramTarget'] as Map),
        );
      }
      final res = await _api.dio.post(
        '/client-uploads/init',
        data: {
          'upload_client_id': _directBatchUploadClientId(batchItems),
          'folder_id': effectiveFolderId == null
              ? null
              : int.parse(effectiveFolderId),
          'auto_rename_duplicates': _settings.state.autoRenameDuplicates,
          'files': batchItems
              .map(
                (item) => {
                  'local_id': item.localId,
                  'original_filename': item.name,
                  'mime_type': item.mimeType,
                  'file_type': detectFileKind(item.name, item.mimeType).name,
                  'size_bytes': item.size,
                  'local_modified_at': item.localModifiedAt
                      ?.toUtc()
                      .toIso8601String(),
                  'added_at_millis': item.addedAtMillis,
                  'duration_ms': item.durationMs,
                  'relative_path': item.relativePath,
                  'client_source': item.clientSource,
                  'backup_fingerprint': item.backupFingerprint,
                  'backup_source': item.clientSource == 'gallery_backup'
                      ? 'gallery_backup'
                      : null,
                  'source_kind': item.backupSourceKind,
                  'content_uri': item.contentUri,
                },
              )
              .toList(),
        },
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final batchId = (data['batchId'] as num).toInt();
      final files = (data['files'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final item in batchItems) {
        final file = files
            .where((f) => f['localId'] == item.localId)
            .firstOrNull;
        if (file == null) {
          _setItem(
            item.localId,
            status: UploadStatus.failed,
            error: 'Backend did not create an upload slot for this file.',
            notify: false,
          );
          continue;
        }
        _setItem(
          item.localId,
          name: file['finalFilename'] as String?,
          batchId: batchId,
          fileId: (file['fileId'] as num?)?.toInt(),
          uploadJobId: (file['uploadJobId'] as num?)?.toInt(),
          notify: false,
        );
      }
      _flushSetItemBatch();

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
            backendUserId: user.userId,
            telegramUserId: user.telegramId,
          );
          final commitId = '$batchId:$fileId:${latest.localId}';
          await _pendingCommits.save(
            commitScope,
            PendingTelegramCommit(
              id: commitId,
              backendBaseUrlHash: _pendingCommits.backendBaseUrlHash,
              backendUserId: user.userId,
              telegramUserId: user.telegramId,
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
    } finally {
      for (final item in batchItems) {
        _runningLocalIds.remove(item.localId);
      }
      _flushSetItemBatch(force: true);
      await _refreshIfSettled();
      _pumpQueue();
    }
  }

  Future<Response<dynamic>> _commitClientUploadWithRetry(
    String path,
    Map<String, dynamic> data,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _api.dio.post(path, data: data);
      } catch (err) {
        lastError = err;
        if (attempt == 2) break;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('Metadata commit failed.');
  }

  Future<Map<String, Map<String, dynamic>>> _uploadDirectDerivatives({
    required UploadItem item,
    required Map<String, dynamic> intent,
    required TelegramUploadTarget target,
  }) async {
    if (!_auth.clientDerivativeGenerationEnabled) {
      debugPrint(
        'Direct upload derivatives disabled for ${item.name}: '
        'clientDerivativeGenerationEnabled=false',
      );
      return {};
    }
    final policy = _serverPolicy(intent);
    final requiresThumbnail = _boolish(
      policy['requiresThumbnail'] ?? policy['requires_thumbnail'],
    );
    final requiresPreview = _boolish(
      policy['requiresPreview'] ?? policy['requires_preview'],
    );
    final isHeic =
        item.name.toLowerCase().endsWith('.heic') ||
        item.name.toLowerCase().endsWith('.heif') ||
        item.path.toLowerCase().endsWith('.heic') ||
        item.path.toLowerCase().endsWith('.heif') ||
        item.mimeType.toLowerCase() == 'image/heic' ||
        item.mimeType.toLowerCase() == 'image/heif';
    debugPrint(
      'Direct upload derivatives policy for ${item.name}: '
      'mime=${item.mimeType} heic=$isHeic '
      'requiresThumbnail=$requiresThumbnail requiresPreview=$requiresPreview',
    );
    if (!requiresThumbnail && !requiresPreview) {
      debugPrint(
        'Direct upload derivatives skipped by policy for ${item.name}',
      );
      return {};
    }

    if (requiresThumbnail) {
      _setItem(item.localId, status: UploadStatus.creatingThumbnail);
    }
    if (requiresPreview) {
      _setItem(item.localId, status: UploadStatus.creatingPreview);
    }
    final ClientDerivativeSet generated;
    try {
      generated = await _derivatives.generate(
        localId: item.localId,
        originalPath: item.path,
        originalFilename: item.name,
        mimeType: item.mimeType,
        requiresThumbnail: requiresThumbnail,
        requiresPreview: requiresPreview,
        allowVideoPreview: _boolish(
          policy['allowVideoPreview'] ?? policy['allow_video_preview'],
        ),
      );
    } catch (err) {
      debugPrint('Direct upload derivative generation skipped: $err');
      return {};
    }
    final generatedAssets = generated.assets.toList(growable: false);
    debugPrint(
      'Direct upload derivatives generated for ${item.name}: '
      '${generatedAssets.length} asset(s)',
    );
    final payloads = <String, Map<String, dynamic>>{};
    for (final asset in generatedAssets) {
      final current = _findItem(item.localId);
      if (current == null || current.cancelRequested) break;
      try {
        _setItem(
          item.localId,
          status: asset.variant == 'thumbnail'
              ? UploadStatus.uploadingThumbnailToTelegram
              : UploadStatus.uploadingPreviewToTelegram,
          serverProgress: 0,
        );
        final uploaded = await _telegram.uploadDerivative(
          filePath: asset.path,
          filename: asset.filename,
          mimeType: asset.mimeType,
          sizeBytes: asset.sizeBytes,
          target: target,
          variant: asset.variant,
          transferId: '${item.uploadClientId}:${asset.variant}',
        );
        payloads[asset.variant] = uploaded.ref.toCommitJson(
          filename: asset.filename,
          mimeType: asset.mimeType,
          sizeBytes: asset.sizeBytes,
          widthPx: asset.widthPx,
          heightPx: asset.heightPx,
          durationMs: asset.durationMs,
        );
        debugPrint(
          'Direct upload ${asset.variant} uploaded for ${item.name}: '
          '${asset.sizeBytes} bytes',
        );
      } catch (err) {
        debugPrint('Direct upload ${asset.variant} skipped: $err');
      } finally {
        await _safeDeleteLocalFile(asset.path);
      }
    }
    return payloads;
  }

  Map<String, dynamic> _serverPolicy(Map<String, dynamic> intent) {
    final raw = intent['serverPolicy'] ?? intent['server_policy'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  bool _boolish(Object? value) => value == true || value == 'true';

  int? _intish(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _directBatchUploadClientId(List<UploadItem> batchItems) {
    final sessionId = uploadSessionId ??= _uuid.v4();
    final chunkId = batchItems.map((item) => item.localId).join(',');
    return '$sessionId:$chunkId';
  }

  // ignore: unused_element
  void _startPollingBatch(int batchId) {
    _stopPollingBatch(batchId);
    _pollTimersByBatchId[batchId] = Timer.periodic(
      UploadController.pollInterval,
      (_) => _pollBatch(batchId),
    );
  }

  Future<void> _pollBatch(int batchId) async {
    final batchItems = items.where((i) => i.batchId == batchId).toList();
    if (batchItems.isEmpty || !_pollingBatchIds.add(batchId)) return;
    try {
      final res = await _api.dio.get('/upload-batches/$batchId');
      final data = Map<String, dynamic>.from(res.data as Map);
      final files = (data['files'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final current in batchItems) {
        if (current.cancelRequested) continue;
        final matched = files
            .where((f) => f['upload_job_id'] == current.uploadJobId)
            .firstOrNull;
        if (matched == null) continue;
        final status = UploadStatus.fromBackendStatus('${matched['status']}');
        final total =
            (matched['total_bytes'] as num?)?.toDouble() ??
            current.size.toDouble();
        final done = (matched['progress_bytes'] as num?)?.toDouble() ?? 0;
        final serverProgress = status == UploadStatus.uploaded
            ? 1.0
            : total > 0
            ? (done / total).clamp(0.0, 1.0)
            : current.serverProgress;
        final thumbReady =
            '${matched['thumbnail_status'] ?? ''}' == 'available';
        if (status == UploadStatus.uploaded &&
            current.status != UploadStatus.uploaded) {
          if (current.deleteLocalOnComplete) {
            unawaited(_safeDeleteLocalFile(current.path));
          }
        }
        _setItem(
          current.localId,
          status: status,
          serverProgress: serverProgress,
          fileId: (matched['file_id'] as num?)?.toInt(),
          error: matched['error'] as String?,
          thumbnailReady: thumbReady,
        );
      }
      final updated = items.where((i) => i.batchId == batchId).toList();
      final allUploaded =
          updated.isNotEmpty &&
          updated.every((i) => _isTerminalStatus(i.status));
      if (allUploaded) {
        final finishedTime = _batchUploadFinishedTimes.putIfAbsent(
          batchId,
          () => DateTime.now(),
        );
        final elapsedSeconds = DateTime.now()
            .difference(finishedTime)
            .inSeconds;
        final allDone =
            updated.every((i) => !_needsThumbnail(i)) || elapsedSeconds > 25;
        if (allDone) {
          _stopPollingBatch(batchId);
          _batchUploadFinishedTimes.remove(batchId);
          await _refreshIfSettled();
        }
      }
    } catch (err) {
      _stopPollingBatch(batchId);
      for (final item in batchItems) {
        _setItem(
          item.localId,
          status: UploadStatus.failed,
          error: _api.errorMessage(err, 'Upload polling failed.'),
        );
      }
      await _refreshIfSettled();
    } finally {
      _pollingBatchIds.remove(batchId);
    }
  }
}
