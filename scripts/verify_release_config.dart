import 'dart:io';

/// Client assets are extractable. Never print configuration values in diagnostics.
void main(List<String> args) {
  final file = File(args.isEmpty ? '.env.local' : args.single);
  if (!file.existsSync()) {
    stderr.writeln('Release configuration is missing.');
    exitCode = 1;
    return;
  }
  final rejected = privateConfigurationKeys(file.readAsStringSync());
  if (rejected.isNotEmpty) {
    stderr.writeln(
      'Release assets contain server/private credentials: ${rejected.join(', ')}. Remove them from client configuration before packaging.',
    );
    exitCode = 1;
  }
}

Set<String> privateConfigurationKeys(String content) {
  const forbidden = {
    'GITHUB_TOKEN',
    'JWT_SECRET',
    'DATABASE_URL',
    'TELEGRAM_SESSION_ENCRYPTION_KEY',
  };
  final rejected = <String>{};
  for (final line in content.split('\n')) {
    final match = RegExp(
      r'^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$',
    ).firstMatch(line);
    if (match == null || !forbidden.contains(match[1])) continue;
    final value = match[2]!.split('#').first.trim();
    if (value.isNotEmpty && value != "''" && value != '""')
      rejected.add(match[1]!);
  }
  return rejected;
}
