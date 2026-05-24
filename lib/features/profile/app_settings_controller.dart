import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GalleryBackupIndexingStrategy {
  mediaStoreOnly('media_store_only', 'MediaStore indexing only'),
  filePathOnly('file_path_only', 'File path scanning only'),
  mediaStoreAndFilePath(
    'media_store_and_file_path',
    'MediaStore + file path scanning',
  );

  const GalleryBackupIndexingStrategy(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static GalleryBackupIndexingStrategy fromStorage(String? value) {
    return GalleryBackupIndexingStrategy.values.firstWhere(
      (strategy) => strategy.storageValue == value,
      orElse: () => GalleryBackupIndexingStrategy.mediaStoreOnly,
    );
  }
}

class AppSettingsState {
  const AppSettingsState({
    this.askBeforeLargeUploads = true,
    this.uploadOnMobileData = true,
    this.autoRenameDuplicates = false,
    this.trashEnabled = true,
    this.confirmPublicShares = false,
    this.clearCacheOnSignOut = true,
    this.uploadCompletedAlerts = false,
    this.uploadFailedAlerts = false,
    this.galleryBackupEnabled = false,
    this.galleryBackupWifiOnly = true,
    this.galleryBackupScanLimit = 80,
    this.galleryBackupQueueLimit = 12,
    this.galleryBackupIndexingStrategy =
        GalleryBackupIndexingStrategy.mediaStoreOnly,
    this.loaded = false,
  });

  final bool askBeforeLargeUploads;
  final bool uploadOnMobileData;
  final bool autoRenameDuplicates;
  final bool trashEnabled;
  final bool confirmPublicShares;
  final bool clearCacheOnSignOut;
  final bool uploadCompletedAlerts;
  final bool uploadFailedAlerts;
  final bool galleryBackupEnabled;
  final bool galleryBackupWifiOnly;
  final int galleryBackupScanLimit;
  final int galleryBackupQueueLimit;
  final GalleryBackupIndexingStrategy galleryBackupIndexingStrategy;
  final bool loaded;

  AppSettingsState copyWith({
    bool? askBeforeLargeUploads,
    bool? uploadOnMobileData,
    bool? autoRenameDuplicates,
    bool? trashEnabled,
    bool? confirmPublicShares,
    bool? clearCacheOnSignOut,
    bool? uploadCompletedAlerts,
    bool? uploadFailedAlerts,
    bool? galleryBackupEnabled,
    bool? galleryBackupWifiOnly,
    int? galleryBackupScanLimit,
    int? galleryBackupQueueLimit,
    GalleryBackupIndexingStrategy? galleryBackupIndexingStrategy,
    bool? loaded,
  }) {
    return AppSettingsState(
      askBeforeLargeUploads:
          askBeforeLargeUploads ?? this.askBeforeLargeUploads,
      uploadOnMobileData: uploadOnMobileData ?? this.uploadOnMobileData,
      autoRenameDuplicates: autoRenameDuplicates ?? this.autoRenameDuplicates,
      trashEnabled: trashEnabled ?? this.trashEnabled,
      confirmPublicShares: confirmPublicShares ?? this.confirmPublicShares,
      clearCacheOnSignOut: clearCacheOnSignOut ?? this.clearCacheOnSignOut,
      uploadCompletedAlerts:
          uploadCompletedAlerts ?? this.uploadCompletedAlerts,
      uploadFailedAlerts: uploadFailedAlerts ?? this.uploadFailedAlerts,
      galleryBackupEnabled: galleryBackupEnabled ?? this.galleryBackupEnabled,
      galleryBackupWifiOnly:
          galleryBackupWifiOnly ?? this.galleryBackupWifiOnly,
      galleryBackupScanLimit:
          galleryBackupScanLimit ?? this.galleryBackupScanLimit,
      galleryBackupQueueLimit:
          galleryBackupQueueLimit ?? this.galleryBackupQueueLimit,
      galleryBackupIndexingStrategy:
          galleryBackupIndexingStrategy ?? this.galleryBackupIndexingStrategy,
      loaded: loaded ?? this.loaded,
    );
  }
}

final appSettingsControllerProvider =
    ChangeNotifierProvider<AppSettingsController>((ref) {
      return AppSettingsController()..load();
    });

class AppSettingsController extends ChangeNotifier {
  static const _askLargeKey = 'settings_ask_large_uploads';
  static const _mobileDataKey = 'settings_upload_mobile_data';
  static const _renameDuplicatesKey = 'settings_auto_rename_duplicates';
  static const _trashKey = 'settings_trash_enabled';
  static const _shareConfirmKey = 'settings_confirm_public_shares';
  static const _clearCacheSignOutKey = 'settings_clear_cache_sign_out';
  static const _uploadCompleteAlertsKey = 'settings_upload_complete_alerts';
  static const _uploadFailedAlertsKey = 'settings_upload_failed_alerts';
  static const _galleryBackupEnabledKey = 'settings_gallery_backup_enabled';
  static const _galleryBackupWifiOnlyKey = 'settings_gallery_backup_wifi_only';
  static const _galleryBackupScanLimitKey = 'settings_gallery_scan_limit';
  static const _galleryBackupQueueLimitKey = 'settings_gallery_queue_limit';
  static const _galleryBackupIndexingStrategyKey =
      'settings_gallery_indexing_strategy';

  AppSettingsState state = const AppSettingsState();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettingsState(
      askBeforeLargeUploads: prefs.getBool(_askLargeKey) ?? true,
      uploadOnMobileData: prefs.getBool(_mobileDataKey) ?? true,
      autoRenameDuplicates: prefs.getBool(_renameDuplicatesKey) ?? false,
      trashEnabled: prefs.getBool(_trashKey) ?? true,
      confirmPublicShares: prefs.getBool(_shareConfirmKey) ?? false,
      clearCacheOnSignOut: prefs.getBool(_clearCacheSignOutKey) ?? true,
      uploadCompletedAlerts: prefs.getBool(_uploadCompleteAlertsKey) ?? false,
      uploadFailedAlerts: prefs.getBool(_uploadFailedAlertsKey) ?? false,
      galleryBackupEnabled: prefs.getBool(_galleryBackupEnabledKey) ?? false,
      galleryBackupWifiOnly: prefs.getBool(_galleryBackupWifiOnlyKey) ?? true,
      galleryBackupScanLimit: _boundedPositiveInt(
        prefs.getInt(_galleryBackupScanLimitKey),
        80,
      ),
      galleryBackupQueueLimit: _boundedPositiveInt(
        prefs.getInt(_galleryBackupQueueLimitKey),
        12,
      ),
      galleryBackupIndexingStrategy: GalleryBackupIndexingStrategy.fromStorage(
        prefs.getString(_galleryBackupIndexingStrategyKey),
      ),
      loaded: true,
    );
    notifyListeners();
  }

  Future<void> setAskBeforeLargeUploads(bool value) =>
      _set(_askLargeKey, state.copyWith(askBeforeLargeUploads: value));

  Future<void> setUploadOnMobileData(bool value) =>
      _set(_mobileDataKey, state.copyWith(uploadOnMobileData: value));

  Future<void> setAutoRenameDuplicates(bool value) =>
      _set(_renameDuplicatesKey, state.copyWith(autoRenameDuplicates: value));

  Future<void> setTrashEnabled(bool value) =>
      _set(_trashKey, state.copyWith(trashEnabled: value));

  Future<void> setConfirmPublicShares(bool value) =>
      _set(_shareConfirmKey, state.copyWith(confirmPublicShares: value));

  Future<void> setClearCacheOnSignOut(bool value) =>
      _set(_clearCacheSignOutKey, state.copyWith(clearCacheOnSignOut: value));

  Future<void> setUploadCompletedAlerts(bool value) => _set(
    _uploadCompleteAlertsKey,
    state.copyWith(uploadCompletedAlerts: value),
  );

  Future<void> setUploadFailedAlerts(bool value) =>
      _set(_uploadFailedAlertsKey, state.copyWith(uploadFailedAlerts: value));

  Future<void> setGalleryBackupEnabled(bool value) => _set(
    _galleryBackupEnabledKey,
    state.copyWith(galleryBackupEnabled: value),
  );

  Future<void> setGalleryBackupWifiOnly(bool value) => _set(
    _galleryBackupWifiOnlyKey,
    state.copyWith(galleryBackupWifiOnly: value),
  );

  Future<void> setGalleryBackupScanLimit(int value) => _set(
    _galleryBackupScanLimitKey,
    state.copyWith(galleryBackupScanLimit: value.clamp(1, 500).toInt()),
  );

  Future<void> setGalleryBackupQueueLimit(int value) => _set(
    _galleryBackupQueueLimitKey,
    state.copyWith(galleryBackupQueueLimit: value.clamp(1, 100).toInt()),
  );

  Future<void> setGalleryBackupIndexingStrategy(
    GalleryBackupIndexingStrategy value,
  ) => _set(
    _galleryBackupIndexingStrategyKey,
    state.copyWith(galleryBackupIndexingStrategy: value),
  );

  Future<void> _set(String key, AppSettingsState next) async {
    state = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case _askLargeKey:
        await prefs.setBool(key, next.askBeforeLargeUploads);
      case _mobileDataKey:
        await prefs.setBool(key, next.uploadOnMobileData);
      case _renameDuplicatesKey:
        await prefs.setBool(key, next.autoRenameDuplicates);
      case _trashKey:
        await prefs.setBool(key, next.trashEnabled);
      case _shareConfirmKey:
        await prefs.setBool(key, next.confirmPublicShares);
      case _clearCacheSignOutKey:
        await prefs.setBool(key, next.clearCacheOnSignOut);
      case _uploadCompleteAlertsKey:
        await prefs.setBool(key, next.uploadCompletedAlerts);
      case _uploadFailedAlertsKey:
        await prefs.setBool(key, next.uploadFailedAlerts);
      case _galleryBackupEnabledKey:
        await prefs.setBool(key, next.galleryBackupEnabled);
      case _galleryBackupWifiOnlyKey:
        await prefs.setBool(key, next.galleryBackupWifiOnly);
      case _galleryBackupScanLimitKey:
        await prefs.setInt(key, next.galleryBackupScanLimit);
      case _galleryBackupQueueLimitKey:
        await prefs.setInt(key, next.galleryBackupQueueLimit);
      case _galleryBackupIndexingStrategyKey:
        await prefs.setString(
          key,
          next.galleryBackupIndexingStrategy.storageValue,
        );
    }
  }

  static int _boundedPositiveInt(int? value, int fallback) {
    final next = value ?? fallback;
    return next < 1 ? fallback : next;
  }
}
