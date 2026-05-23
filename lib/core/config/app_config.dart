import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class AppConfig {
  static const _fallbackApiBaseUrl = 'http://192.168.1.5:8000/api';

  static String get apiBaseUrl {
    final value = dotenv.maybeGet('API_BASE_URL');
    return (value == null || value.isEmpty) ? _fallbackApiBaseUrl : value;
  }

  /// The public GitHub repository URL for TeleDrive.
  static const repositoryUrl = 'https://github.com/caamer20/Telegram-Drive';

  /// The official Instagram URL.
  static const instagramUrl = 'https://www.instagram.com/devsdocode_';

  /// The official X (Twitter) URL.
  static const twitterUrl = 'https://x.com/Anand_Sreejan';

  /// The official YouTube URL.
  static const youtubeUrl = 'https://www.youtube.com/@DevsDoCode';

  /// The current version of the application.
  static const appVersion = '2.1.8';

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
}
