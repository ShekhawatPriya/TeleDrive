import 'package:flutter_test/flutter_test.dart';
import '../scripts/verify_release_config.dart';

void main() {
  test('release validation allows public and blank client configuration', () {
    expect(
      privateConfigurationKeys(
        'API_BASE_URL=https://example.test\nGITHUB_TOKEN=\nJWT_SECRET=""\n# DATABASE_URL=example',
      ),
      isEmpty,
    );
  });
  test('release validation rejects credential keys without returning values', () {
    final found = privateConfigurationKeys(
      'export GITHUB_TOKEN="private-fixture"\n DATABASE_URL=postgresql://fixture\nTELEGRAM_SESSION_ENCRYPTION_KEY=fixture',
    );
    expect(found, {
      'GITHUB_TOKEN',
      'DATABASE_URL',
      'TELEGRAM_SESSION_ENCRYPTION_KEY',
    });
    expect(found.join(), isNot(contains('private-fixture')));
  });
}
