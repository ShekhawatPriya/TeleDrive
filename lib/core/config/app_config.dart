import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppConfig {
  static const _fallbackApiBaseUrl = 'http://10.0.2.2:8000/api';

  // GitHub repository that hosts the source code AND the published Releases
  // (APK + latest.json) that drive both the Changelog and the in-app updater.
  static const _fallbackGithubOwner = 'ShekhawatPriya';
  static const _fallbackGithubRepo = 'TG-Cloud-Drive';
  static String get _fallbackUpdateManifestUrl =>
      'https://github.com/$githubOwner/$githubRepo/releases/latest/download/latest.json';

  static String get apiBaseUrl {
    return _value('API_BASE_URL') ?? _fallbackApiBaseUrl;
  }

  static int? get telegramApiId {
    final value = _value('TELEGRAM_API_ID');
    return value == null ? null : int.tryParse(value);
  }

  static String get telegramApiHash => _value('TELEGRAM_API_HASH') ?? '';

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

  static int get tdlibE2eCommitDelaySeconds =>
      _int('TDLIB_E2E_COMMIT_DELAY_SECONDS', fallback: 0);

  static String get appUpdateManifestUrl {
    return _value('APP_UPDATE_MANIFEST_URL') ?? _fallbackUpdateManifestUrl;
  }

  /// GitHub repository owner (user/org) hosting the source and Releases.
  static String get githubOwner {
    return _value('GITHUB_REPO_OWNER') ?? _fallbackGithubOwner;
  }

  /// GitHub repository name hosting the source and Releases.
  static String get githubRepo {
    return _value('GITHUB_REPO_NAME') ?? _fallbackGithubRepo;
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
  /// Compiled values remain extractable from an APK. Prefer leaving this empty
  /// for public releases; never ship a privileged long-lived token.
  static String get githubToken => _value('GITHUB_TOKEN') ?? '';

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
  static Future<void> openRepository() => _openExternal(repositoryUrl);

  /// Launches the Instagram URL in the user's default browser.
  static Future<void> openInstagram() => _openExternal(instagramUrl);

  /// Launches the Twitter/X URL in the user's default browser.
  static Future<void> openTwitter() => _openExternal(twitterUrl);

  /// Launches the YouTube URL in the user's default browser.
  static Future<void> openYouTube() => _openExternal(youtubeUrl);

  static Future<void> _openExternal(String value) async {
    final uri = Uri.parse(value);
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

  static String? _value(String key) {
    final value = dotenv.maybeGet(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static bool _bool(String key, {required bool fallback}) {
    final value = _value(key);
    if (value == null) return fallback;
    return {'1', 'true', 'yes', 'on'}.contains(value.toLowerCase());
  }

  static int _int(String key, {required int fallback}) {
    final value = _value(key);
    return value == null ? fallback : int.tryParse(value) ?? fallback;
  }
}
