part of 'gallery_backup_asset_store.dart';

extension _GalleryBackupAssetStoreHelpers on GalleryBackupAssetStore {
  GalleryBackupAssetRecord _withAssetMetadata(
    GalleryBackupAssetRecord record,
    GalleryMediaAsset asset, {
    GalleryBackupAssetStatus? status,
    required int updatedAtMillis,
    int? uploadedAtMillis,
    bool clearFailure = false,
    bool clearCleanupFailure = false,
  }) {
    return record.copyWith(
      status: status,
      updatedAtMillis: updatedAtMillis,
      uploadedAtMillis: uploadedAtMillis,
      contentUri: asset.contentUri,
      path: asset.path,
      name: asset.name,
      sizeBytes: asset.sizeBytes,
      mimeType: asset.mimeType,
      mediaType: asset.mediaType,
      sourceKind: asset.sourceKind,
      relativePath: asset.relativePath,
      modifiedAtMillis: asset.modifiedAtMillis,
      addedAtMillis: asset.addedAtMillis,
      durationMs: asset.durationMs,
      clearFailure: clearFailure,
      clearCleanupFailure: clearCleanupFailure,
    );
  }

  GalleryBackupAssetRecord _empty(String fingerprint, int now) {
    return GalleryBackupAssetRecord(
      fingerprint: fingerprint,
      status: GalleryBackupAssetStatus.discovered,
      updatedAtMillis: now,
    );
  }

  String _mediaTypeFor(String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('video/')) return 'video';
    if (mime.startsWith('image/')) return 'image';
    return 'unknown';
  }

  Future<void> _scheduleSave(String scope, {required bool terminal}) async {
    if (terminal) {
      GalleryBackupAssetStore._saveTimers.remove(scope)?.cancel();
      await _enqueueSave(scope);
      return;
    }
    GalleryBackupAssetStore._saveTimers.remove(scope)?.cancel();
    GalleryBackupAssetStore._saveTimers[scope] = Timer(
      GalleryBackupAssetStore._debounce,
      () {
        GalleryBackupAssetStore._saveTimers.remove(scope);
        // Fire and forget; chained through _saveChain to preserve ordering.
        _enqueueSave(scope);
      },
    );
  }

  Future<void> _enqueueSave(String scope) {
    final prev =
        GalleryBackupAssetStore._saveChain[scope] ?? Future<void>.value();
    final next = prev.catchError((_) {}).then((_) => _flushSave(scope));
    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      if (identical(GalleryBackupAssetStore._saveChain[scope], tracked)) {
        GalleryBackupAssetStore._saveChain.remove(scope);
      }
    });
    GalleryBackupAssetStore._saveChain[scope] = tracked;
    return tracked;
  }

  Future<void> _flushSave(String scope) async {
    final records = GalleryBackupAssetStore._cache[scope];
    if (records == null) return;
    final snapshot = <Map<String, dynamic>>[
      for (final r in records.values) r.toJson(),
    ];
    String encoded;
    try {
      encoded = await compute(_encodeRecords, snapshot);
    } catch (err, stack) {
      debugPrint(
        'GalleryBackupAssetStore compute encode failed, '
        'falling back to in-isolate: $err',
      );
      debugPrintStack(stackTrace: stack);
      encoded = _encodeRecords(snapshot);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(scope), encoded);
  }
}

String _encodeRecords(List<Map<String, dynamic>> snapshot) {
  snapshot.sort(
    (a, b) =>
        (b['updatedAtMillis'] as int).compareTo(a['updatedAtMillis'] as int),
  );
  final trimmed = snapshot.length > GalleryBackupAssetStore._cap
      ? snapshot.sublist(0, GalleryBackupAssetStore._cap)
      : snapshot;
  return jsonEncode({for (final r in trimmed) r['fingerprint'] as String: r});
}

String _key(String scope) => '${GalleryBackupAssetStore._prefix}_$scope';
