part of '../upload_controller.dart';

extension _UploadDirect on UploadController {
  String _directBatchUploadClientId(List<UploadItem> batchItems) {
    final sessionId = uploadSessionId ??= _uuid.v4();
    final chunkId = batchItems.map((item) => item.localId).join(',');
    return '$sessionId:$chunkId';
  }

  Future<void> _uploadManyDirect(List<UploadItem> batchItems) async {
    final blockedOnMobileData = await _isBlockedOnMobileData();
    if (!batchItems.any(_isCurrentUpload)) return;
    if (blockedOnMobileData) {
      for (final item in batchItems) {
        if (!_isCurrentUpload(item)) continue;
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
    if (!batchItems.any(_isCurrentUpload)) return;
    final authorized = await _telegram.isAuthorized;
    if (!batchItems.any(_isCurrentUpload)) return;
    if (!authorized) {
      throw const TelegramClientUnavailableException(
        'Local TDLib is not authorized.',
        code: 'tdlib_auth_required',
      );
    }
    for (final item in batchItems) {
      if (!_isCurrentUpload(item)) continue;
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
    if (!batchItems.any(_isCurrentUpload)) return;
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
      final file = files.where((f) => f['localId'] == item.localId).firstOrNull;
      if (file == null) {
        if (!_isCurrentUpload(item)) continue;
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

    await _uploadDirectFiles(
      batchItems: batchItems,
      files: files,
      preparedTarget: preparedTarget,
      batchId: batchId,
      backendUserId: user.userId,
      telegramUserId: user.telegramId,
    );
  }
}
