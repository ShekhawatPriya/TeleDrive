import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/media/gallery_media_scanner.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';
import '../drive/drive_repository.dart';
import '../upload/upload_controller.dart';
import '../upload/upload_models.dart';
import 'app_settings_controller.dart';
import 'gallery_backup_asset_store.dart';

final galleryBackupControllerProvider =
    ChangeNotifierProvider<GalleryBackupController>((ref) {
      final controller = GalleryBackupController(
        settings: ref.read(appSettingsControllerProvider),
        auth: ref.read(authControllerProvider),
        uploads: ref.read(uploadControllerProvider),
        drive: ref.read(driveRepositoryProvider),
      );
      ref.onDispose(controller.dispose);
      controller.start();
      return controller;
    });

@immutable
class GalleryBackupDiagnostics {
  const GalleryBackupDiagnostics({
    this.lastScanStartedAt,
    this.lastScanCompletedAt,
    this.scanDuration,
    this.indexingStrategy = GalleryBackupIndexingStrategy.mediaStoreOnly,
    this.mediaStoreItemsScanned = 0,
    this.pathItemsScanned = 0,
    this.mergedCandidates = 0,
    this.skippedAlreadyUploaded = 0,
    this.skippedAlreadyQueued = 0,
    this.skippedPermission = 0,
    this.skippedInvalid = 0,
    this.enqueued = 0,
    this.lastError,
    this.lastEnqueueError,
    this.lastUploadCompleteMarker,
    this.scanLimit = 80,
    this.queueLimit = 12,
    this.notes = const [],
  });

  final DateTime? lastScanStartedAt;
  final DateTime? lastScanCompletedAt;
  final Duration? scanDuration;
  final GalleryBackupIndexingStrategy indexingStrategy;
  final int mediaStoreItemsScanned;
  final int pathItemsScanned;
  final int mergedCandidates;
  final int skippedAlreadyUploaded;
  final int skippedAlreadyQueued;
  final int skippedPermission;
  final int skippedInvalid;
  final int enqueued;
  final String? lastError;
  final String? lastEnqueueError;
  final DateTime? lastUploadCompleteMarker;
  final int scanLimit;
  final int queueLimit;
  final List<String> notes;

  GalleryBackupDiagnostics copyWith({
    DateTime? lastScanStartedAt,
    DateTime? lastScanCompletedAt,
    Duration? scanDuration,
    GalleryBackupIndexingStrategy? indexingStrategy,
    int? mediaStoreItemsScanned,
    int? pathItemsScanned,
    int? mergedCandidates,
    int? skippedAlreadyUploaded,
    int? skippedAlreadyQueued,
    int? skippedPermission,
    int? skippedInvalid,
    int? enqueued,
    String? lastError,
    bool clearLastError = false,
    String? lastEnqueueError,
    bool clearLastEnqueueError = false,
    DateTime? lastUploadCompleteMarker,
    int? scanLimit,
    int? queueLimit,
    List<String>? notes,
  }) {
    return GalleryBackupDiagnostics(
      lastScanStartedAt: lastScanStartedAt ?? this.lastScanStartedAt,
      lastScanCompletedAt: lastScanCompletedAt ?? this.lastScanCompletedAt,
      scanDuration: scanDuration ?? this.scanDuration,
      indexingStrategy: indexingStrategy ?? this.indexingStrategy,
      mediaStoreItemsScanned:
          mediaStoreItemsScanned ?? this.mediaStoreItemsScanned,
      pathItemsScanned: pathItemsScanned ?? this.pathItemsScanned,
      mergedCandidates: mergedCandidates ?? this.mergedCandidates,
      skippedAlreadyUploaded:
          skippedAlreadyUploaded ?? this.skippedAlreadyUploaded,
      skippedAlreadyQueued: skippedAlreadyQueued ?? this.skippedAlreadyQueued,
      skippedPermission: skippedPermission ?? this.skippedPermission,
      skippedInvalid: skippedInvalid ?? this.skippedInvalid,
      enqueued: enqueued ?? this.enqueued,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      lastEnqueueError: clearLastEnqueueError
          ? null
          : lastEnqueueError ?? this.lastEnqueueError,
      lastUploadCompleteMarker:
          lastUploadCompleteMarker ?? this.lastUploadCompleteMarker,
      scanLimit: scanLimit ?? this.scanLimit,
      queueLimit: queueLimit ?? this.queueLimit,
      notes: notes ?? this.notes,
    );
  }
}

class GalleryBackupController extends ChangeNotifier {
  GalleryBackupController({
    required AppSettingsController settings,
    required AuthController auth,
    required UploadController uploads,
    required DriveRepository drive,
    GalleryMediaScanner scanner = const GalleryMediaScanner(),
    GalleryBackupAssetStore assetStore = const GalleryBackupAssetStore(),
  }) : _settings = settings,
       _auth = auth,
       _uploads = uploads,
       _drive = drive,
       _scanner = scanner,
       _assetStore = assetStore {
    _lastEnabled = _settings.state.galleryBackupEnabled;
    _settings.addListener(_handleSettingsChanged);
    _auth.addListener(_scheduleSoon);
  }

  static const _uuid = Uuid();
  static const _periodicScan = Duration(minutes: 15);
  static const _manualDelayedRescan = Duration(seconds: 8);
  static const _resumeScanThrottle = Duration(minutes: 2);

  final AppSettingsController _settings;
  final AuthController _auth;
  final UploadController _uploads;
  final DriveRepository _drive;
  final GalleryMediaScanner _scanner;
  final GalleryBackupAssetStore _assetStore;
  final Map<String, String> _folderIdCache = {};
  Timer? _timer;
  Timer? _debounce;
  Timer? _delayedRescan;
  bool _running = false;
  bool _lastEnabled = false;
  DateTime? _lastResumeScanAt;

  GalleryBackupDiagnostics diagnostics = const GalleryBackupDiagnostics();

  bool get running => _running;
  String? get lastError => diagnostics.lastError;

  void start() {
    if (_settings.state.galleryBackupEnabled) _scheduleSoon();
    _timer = Timer.periodic(_periodicScan, (_) {
      unawaited(scanNow(reason: 'periodic'));
    });
  }

  Future<void> scanNow({
    String reason = 'manual',
    bool bypassThrottle = true,
    bool scheduleDelayedRescan = true,
  }) async {
    if (_running) return;
    if (!bypassThrottle && diagnostics.lastScanStartedAt != null) {
      final elapsed = DateTime.now().difference(diagnostics.lastScanStartedAt!);
      if (elapsed < _resumeScanThrottle) return;
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
    notifyListeners();

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
              localId: _uuid.v4(),
              uploadClientId: _uuid.v4(),
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
      notifyListeners();
      if (scheduleDelayedRescan && _settings.state.galleryBackupEnabled) {
        _scheduleDelayedRescan();
      }
    }
  }

  Future<void> handleAppResumed() async {
    if (!_settings.state.galleryBackupEnabled) return;
    final now = DateTime.now();
    if (_lastResumeScanAt != null &&
        now.difference(_lastResumeScanAt!) < _resumeScanThrottle) {
      return;
    }
    _lastResumeScanAt = now;
    await scanNow(
      reason: 'resume',
      bypassThrottle: false,
      scheduleDelayedRescan: true,
    );
  }

  void _handleSettingsChanged() {
    final enabled = _settings.state.galleryBackupEnabled;
    if (_lastEnabled == enabled) {
      if (enabled) _scheduleSoon();
      return;
    }
    _lastEnabled = enabled;
    if (enabled) {
      _scheduleSoon();
    } else {
      _debounce?.cancel();
      _delayedRescan?.cancel();
      unawaited(_uploads.pauseQueuedGalleryBackupItems());
    }
  }

  Future<bool> _canScan() async {
    if (!Platform.isAndroid) return false;
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

  void _scheduleSoon() {
    if (!_settings.state.galleryBackupEnabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(scanNow(reason: 'settings', scheduleDelayedRescan: false));
    });
  }

  void _scheduleDelayedRescan() {
    _delayedRescan?.cancel();
    _delayedRescan = Timer(_manualDelayedRescan, () {
      unawaited(
        scanNow(
          reason: 'delayed_rescan',
          bypassThrottle: true,
          scheduleDelayedRescan: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_handleSettingsChanged);
    _auth.removeListener(_scheduleSoon);
    _timer?.cancel();
    _debounce?.cancel();
    _delayedRescan?.cancel();
    super.dispose();
  }
}

enum _BackupResolveDecision { upload, uploaded, queued }
