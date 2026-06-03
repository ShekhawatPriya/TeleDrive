import '../../models/auth_user.dart';
import '../../models/drive_models.dart';
import 'models/community_onboarding.dart';

class BackendFeatureFlags {
  const BackendFeatureFlags({
    this.directTelegramUploadEnabled = false,
    this.directTelegramDownloadEnabled = false,
    this.clientDerivativeGenerationEnabled = false,
    this.galleryBackupEnabled = false,
    this.publicProxyEnabled = true,
  });

  final bool directTelegramUploadEnabled;
  final bool directTelegramDownloadEnabled;
  final bool clientDerivativeGenerationEnabled;
  final bool galleryBackupEnabled;
  final bool publicProxyEnabled;

  factory BackendFeatureFlags.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BackendFeatureFlags();
    return BackendFeatureFlags(
      directTelegramUploadEnabled:
          _boolish(json, const [
            'directTelegramUploadEnabled',
            'direct_telegram_upload_enabled',
          ]) ??
          false,
      directTelegramDownloadEnabled:
          _boolish(json, const [
            'directTelegramDownloadEnabled',
            'direct_telegram_download_enabled',
          ]) ??
          false,
      clientDerivativeGenerationEnabled:
          _boolish(json, const [
            'clientDerivativeGenerationEnabled',
            'client_derivative_generation_enabled',
          ]) ??
          false,
      galleryBackupEnabled:
          _boolish(json, const [
            'galleryBackupEnabled',
            'gallery_backup_enabled',
          ]) ??
          false,
      publicProxyEnabled:
          _boolish(json, const [
            'publicProxyEnabled',
            'public_proxy_enabled',
          ]) ??
          true,
    );
  }
}

bool? _boolish(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
  }
  return null;
}

class AuthBootstrapResult {
  const AuthBootstrapResult({
    required this.user,
    required this.telegramConnected,
    this.communityJoinStatus,
    this.communityJoinError,
    this.communityTargets = const [],
    this.drive,
    this.largeUploadThresholdBytes,
    this.phoneNumber,
    this.telegramUserId,
    this.sessionStatus,
    this.requiresReconnect = false,
    this.featureFlags = const BackendFeatureFlags(),
  });

  final AuthUser user;
  final bool? telegramConnected;
  final String? communityJoinStatus;
  final String? communityJoinError;
  final List<CommunityTarget> communityTargets;
  final DriveSnapshot? drive;
  final int? largeUploadThresholdBytes;
  final String? phoneNumber;
  final int? telegramUserId;
  final String? sessionStatus;
  final bool requiresReconnect;
  final BackendFeatureFlags featureFlags;
}
