import 'package:url_launcher/url_launcher.dart';

class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.3:8000/api',
  );

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
