import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppConfig {
  static const _fallbackApiBaseUrl = 'http://192.168.1.5:8000/api';
  static const _dartDefineApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  // GitHub repository that hosts the source code AND the published Releases
  // (APK + latest.json) that drive both the Changelog and the in-app updater.
  static const _fallbackGithubOwner = 'ShekhawatPriya';
  static const _fallbackGithubRepo = 'TG-Cloud-Drive';
  static const _dartDefineGithubOwner = String.fromEnvironment(
    'GITHUB_REPO_OWNER',
  );
  static const _dartDefineGithubRepo = String.fromEnvironment(
    'GITHUB_REPO_NAME',
  );
  static const _dartDefineGithubToken = String.fromEnvironment('GITHUB_TOKEN');

  static String get _fallbackUpdateManifestUrl =>
      'https://github.com/$githubOwner/$githubRepo/releases/latest/download/latest.json';
  static const _dartDefineUpdateManifestUrl = String.fromEnvironment(
    'APP_UPDATE_MANIFEST_URL',
  );

  static String get apiBaseUrl {
    if (_dartDefineApiBaseUrl.trim().isNotEmpty) {
      return _dartDefineApiBaseUrl.trim();
    }
    final value = dotenv.maybeGet('API_BASE_URL');
    return (value == null || value.isEmpty) ? _fallbackApiBaseUrl : value;
  }

  static int? get telegramApiId {
    final value = dotenv.maybeGet('TELEGRAM_API_ID');
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value.trim());
  }

  static String get telegramApiHash =>
      dotenv.maybeGet('TELEGRAM_API_HASH')?.trim() ?? '';

  static bool get telegramApiConfigured =>
      telegramApiId != null && telegramApiHash.isNotEmpty;

  static bool get directTelegramUploadEnabled =>
      _bool('DIRECT_TELEGRAM_UPLOAD_ENABLED', fallback: true);

  static bool get directTelegramDownloadEnabled =>
      _bool('DIRECT_TELEGRAM_DOWNLOAD_ENABLED', fallback: true);

  static bool get clientDerivativeGenerationEnabled =>
      _bool('CLIENT_DERIVATIVE_GENERATION_ENABLED', fallback: false);

  static bool get galleryBackupEnabled =>
      _bool('GALLERY_BACKUP_ENABLED', fallback: true);

  static int get maxConcurrentTelegramUploads =>
      _int('MAX_CONCURRENT_TELEGRAM_UPLOADS', fallback: 2);

  static int get maxConcurrentDerivativeTasks =>
      _int('MAX_CONCURRENT_DERIVATIVE_TASKS', fallback: 2);

  static int get maxConcurrentGalleryUploads =>
      _int('MAX_CONCURRENT_GALLERY_UPLOADS', fallback: 1);

  static int get tdlibE2eCommitDelaySeconds =>
      _int('TDLIB_E2E_COMMIT_DELAY_SECONDS', fallback: 0);

  static String get appUpdateManifestUrl {
    if (_dartDefineUpdateManifestUrl.trim().isNotEmpty) {
      return _dartDefineUpdateManifestUrl.trim();
    }
    final value = dotenv.maybeGet('APP_UPDATE_MANIFEST_URL');
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return _fallbackUpdateManifestUrl;
  }

  /// GitHub repository owner (user/org) hosting the source and Releases.
  static String get githubOwner {
    if (_dartDefineGithubOwner.trim().isNotEmpty) {
      return _dartDefineGithubOwner.trim();
    }
    final value = dotenv.maybeGet('GITHUB_REPO_OWNER');
    return (value == null || value.trim().isEmpty)
        ? _fallbackGithubOwner
        : value.trim();
  }

  /// GitHub repository name hosting the source and Releases.
  static String get githubRepo {
    if (_dartDefineGithubRepo.trim().isNotEmpty) {
      return _dartDefineGithubRepo.trim();
    }
    final value = dotenv.maybeGet('GITHUB_REPO_NAME');
    return (value == null || value.trim().isEmpty)
        ? _fallbackGithubRepo
        : value.trim();
  }

  /// GitHub REST endpoint listing all Releases for the configured repository.
  static String get githubReleasesApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases';

  /// GitHub REST endpoint for the single latest published Release. Used by the
  /// in-app updater to read `latest.json` from a private repo (the public
  /// `releases/latest/download/...` path 404s when the repo is private).
  static String get githubLatestReleaseApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// Optional personal access token for the GitHub API. Empty for public
  /// repositories; only needed for private repos or to raise the rate limit.
  ///
  /// Resolution order mirrors the other config values: a compile-time
  /// `--dart-define=GITHUB_TOKEN=...` wins (keeps the token out of the bundled
  /// `.env.local` asset for production builds), then dotenv, then empty.
  static String get githubToken {
    if (_dartDefineGithubToken.trim().isNotEmpty) {
      return _dartDefineGithubToken.trim();
    }
    return dotenv.maybeGet('GITHUB_TOKEN')?.trim() ?? '';
  }

  static bool get appUpdateChecksEnabled =>
      _bool('APP_UPDATE_CHECKS_ENABLED', fallback: true);

  static int get appUpdateCheckIntervalMinutes =>
      _int('APP_UPDATE_CHECK_INTERVAL_MINUTES', fallback: 30);

  /// The public GitHub repository URL for TeleDrive.
  static String get repositoryUrl =>
      'https://github.com/$githubOwner/$githubRepo';

  /// The official Instagram URL.
  static const instagramUrl = 'https://www.instagram.com/devsdocode_';

  /// The official X (Twitter) URL.
  static const twitterUrl = 'https://x.com/Anand_Sreejan';

  /// The official YouTube URL.
  static const youtubeUrl = 'https://www.youtube.com/@DevsDoCode';

  static String _packageVersion = '0.0.0';

  /// The current version of the application, populated at startup from
  /// the installed package metadata via [bootstrap].
  static String get appVersion => _packageVersion;

  /// Loads runtime metadata that needs platform calls (e.g. package version).
  /// Call once during app startup before [runApp].
  static Future<void> bootstrap() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) _packageVersion = info.version;
    } catch (_) {
      // Leave the fallback in place if the platform channel isn't available
      // (e.g. unit tests without a binding).
    }
  }

  /// Launches the repository URL in the user's default browser.
  static Future<void> openRepository() async {
    final uri = Uri.parse(repositoryUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Launches the Instagram URL in the user's default browser.
  static Future<void> openInstagram() async {
    final uri = Uri.parse(instagramUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Launches the Twitter/X URL in the user's default browser.
  static Future<void> openTwitter() async {
    final uri = Uri.parse(twitterUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Launches the YouTube URL in the user's default browser.
  static Future<void> openYouTube() async {
    final uri = Uri.parse(youtubeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Uri apiUri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$apiBaseUrl$normalized');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        for (final entry in query.entries)
          if (entry.value != null) entry.key: '${entry.value}',
      },
    );
  }

  static bool _bool(String key, {required bool fallback}) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) return fallback;
    return {'1', 'true', 'yes', 'on'}.contains(value.toLowerCase().trim());
  }

  static int _int(String key, {required int fallback}) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.trim().isEmpty) return fallback;
    return int.tryParse(value.trim()) ?? fallback;
  }
}
