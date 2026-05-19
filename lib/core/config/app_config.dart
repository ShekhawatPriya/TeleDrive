import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class AppConfig {
  static const _fallbackApiBaseUrl = 'http://192.168.1.15:8000/api';

  static String get apiBaseUrl {
    final value = dotenv.maybeGet('API_BASE_URL');
    return (value == null || value.isEmpty) ? _fallbackApiBaseUrl : value;
  }

  /// The public GitHub repository URL for TeleDrive.
  static const repositoryUrl = 'https://github.com/caamer20/Telegram-Drive';

  /// Launches the repository URL in the user's default browser.
  static Future<void> openRepository() async {
    final uri = Uri.parse(repositoryUrl);
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
