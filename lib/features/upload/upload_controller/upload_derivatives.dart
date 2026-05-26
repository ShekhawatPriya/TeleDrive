part of '../upload_controller.dart';

extension _UploadDerivatives on UploadController {
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
}
