import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _set(String key, AppSettingsState next) async {
    state = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final value = switch (key) {
      _askLargeKey => next.askBeforeLargeUploads,
      _mobileDataKey => next.uploadOnMobileData,
      _renameDuplicatesKey => next.autoRenameDuplicates,
      _trashKey => next.trashEnabled,
      _shareConfirmKey => next.confirmPublicShares,
      _clearCacheSignOutKey => next.clearCacheOnSignOut,
      _uploadCompleteAlertsKey => next.uploadCompletedAlerts,
      _uploadFailedAlertsKey => next.uploadFailedAlerts,
      _galleryBackupEnabledKey => next.galleryBackupEnabled,
      _galleryBackupWifiOnlyKey => next.galleryBackupWifiOnly,
      _ => false,
    };
    await prefs.setBool(key, value);
  }
}
