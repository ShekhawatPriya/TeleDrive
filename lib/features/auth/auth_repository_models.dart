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
      directTelegramUploadEnabled: json['directTelegramUploadEnabled'] == true,
      directTelegramDownloadEnabled:
          json['directTelegramDownloadEnabled'] == true,
      clientDerivativeGenerationEnabled:
          json['clientDerivativeGenerationEnabled'] == true,
      galleryBackupEnabled: json['galleryBackupEnabled'] == true,
      publicProxyEnabled: json['publicProxyEnabled'] != false,
    );
  }
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
