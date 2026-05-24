import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/media/gallery_media_scanner.dart';
import '../auth/auth_controller.dart';
import '../upload/upload_controller.dart';
import '../upload/upload_models.dart';
import 'app_settings_controller.dart';

final galleryBackupControllerProvider =
    ChangeNotifierProvider<GalleryBackupController>((ref) {
      final controller = GalleryBackupController(
        settings: ref.read(appSettingsControllerProvider),
        auth: ref.read(authControllerProvider),
        uploads: ref.read(uploadControllerProvider),
      );
      ref.onDispose(controller.dispose);
      controller.start();
      return controller;
    });

class GalleryBackupController extends ChangeNotifier {
  GalleryBackupController({
    required AppSettingsController settings,
    required AuthController auth,
    required UploadController uploads,
    GalleryMediaScanner scanner = const GalleryMediaScanner(),
  }) : _settings = settings,
       _auth = auth,
       _uploads = uploads,
       _scanner = scanner {
    _settings.addListener(_scheduleSoon);
    _auth.addListener(_scheduleSoon);
  }

  static const _uuid = Uuid();
  static const _scanLimit = 80;
  static const _queueLimit = 12;
  static const _seenCap = 4000;

  final AppSettingsController _settings;
  final AuthController _auth;
  final UploadController _uploads;
  final GalleryMediaScanner _scanner;
  Timer? _timer;
  Timer? _debounce;
  bool _running = false;
  String? lastError;

  void start() {
    _scheduleSoon();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => scanNow());
  }

  Future<void> scanNow() async {
    if (_running || !await _canScan()) return;
    _running = true;
    lastError = null;
    notifyListeners();
    try {
      final permissions = await _mediaPermissions();
      if (!permissions.images && !permissions.videos) return;
      final prefs = await SharedPreferences.getInstance();
      final seenKey = _seenPrefsKey();
      final seen = (prefs.getStringList(seenKey) ?? const <String>[]).toSet();
      final assets = await _scanner.listRecent(
        limit: _scanLimit,
        includeImages: permissions.images,
        includeVideos: permissions.videos,
      );
      final candidates = assets
          .where((asset) => !seen.contains(asset.stableKey))
          .take(_queueLimit)
          .toList();
      if (candidates.isEmpty) return;
      final items = <UploadItem>[];
      final queuedKeys = <String>[];
      for (final asset in candidates) {
        try {
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
              deleteLocalOnComplete: local.deleteWhenDone,
              localModifiedAt: asset.modifiedAtMillis > 0
                  ? DateTime.fromMillisecondsSinceEpoch(asset.modifiedAtMillis)
                  : null,
              relativePath: asset.relativePath,
              durationMs: asset.durationMs,
            ),
          );
          queuedKeys.add(asset.stableKey);
        } catch (err) {
          debugPrint('Gallery backup skipped ${asset.contentUri}: $err');
        }
      }
      if (items.isEmpty) return;
      await _uploads.enqueueGalleryBackupItems(items);
      final nextSeen = <String>[...seen, ...queuedKeys];
      final trimmed = nextSeen.length > _seenCap
          ? nextSeen.sublist(nextSeen.length - _seenCap)
          : nextSeen;
      await prefs.setStringList(seenKey, trimmed);
    } catch (err) {
      lastError = err.toString();
      debugPrint('Gallery backup scan failed: $err');
    } finally {
      _running = false;
      notifyListeners();
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

  String _seenPrefsKey() {
    final userId = _auth.user?.userId ?? 0;
    final telegramId =
        _auth.user?.telegramId ?? _auth.activeAccount?.telegramId ?? 0;
    return 'gallery_backup_seen_${userId}_$telegramId';
  }

  void _scheduleSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(scanNow());
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_scheduleSoon);
    _auth.removeListener(_scheduleSoon);
    _timer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
