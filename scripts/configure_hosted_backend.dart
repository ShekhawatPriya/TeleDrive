import 'dart:io';

/// Apply only public server settings from the tracked example. Telegram client
/// credentials and all unrelated local/release configuration stay untouched.
void main() {
  const keys = {'API_BASE_URL', 'BACKEND_PINNED', 'BACKEND_IDENTITY'};
  final source = File('.env.example').readAsLinesSync();
  final settings = <String, String>{};
  for (final line in source) {
    final split = line.indexOf('=');
    if (split > 0 && keys.contains(line.substring(0, split).trim())) {
      settings[line.substring(0, split).trim()] = line
          .substring(split + 1)
          .trim();
    }
  }
  if (settings.length != keys.length ||
      Uri.tryParse(settings['API_BASE_URL']!)?.scheme != 'https') {
    throw StateError(
      'The tracked hosted backend configuration must contain all three keys and use HTTPS.',
    );
  }
  final target = File('.env.local');
  final lines = target.readAsLinesSync().where((line) {
    final split = line.indexOf('=');
    return split < 0 || !keys.contains(line.substring(0, split).trim());
  });
  target.writeAsStringSync(
    '${lines.join('\n')}\n${settings.entries.map((e) => '${e.key}=${e.value}').join('\n')}\n',
  );
  stdout.writeln('Applied public hosted server configuration.');
}
