import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_m_fsdk/core/config/app_config.dart';
import 'package:flutter_m_fsdk/core/network/backend_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => dotenv.testLoad(fileInput: ''));
  test('HTTPS addresses retain their standard port', () {
    dotenv.testLoad(fileInput: '');
    expect(
      BackendResolver.normalizeBackendUrl('https://drive.example/api'),
      'https://drive.example/api',
    );
    expect(
      BackendResolver.normalizeBackendUrl('http://drive.example'),
      'http://drive.example/api',
    );
    expect(
      BackendResolver.normalizeBackendUrl('192.168.1.2'),
      'http://192.168.1.2:8000/api',
    );
    expect(
      BackendResolver.normalizeBackendUrl('https://drive.example:8443/'),
      'https://drive.example:8443/api',
    );
  });
  test('VPS migration preserves the legacy local identity', () {
    dotenv.testLoad(fileInput: '');
    final old = AppConfig.apiBaseUrl;
    dotenv.testLoad(
      fileInput:
          'API_BASE_URL=https://drive.example/api\nBACKEND_IDENTITY=legacy-local\nBACKEND_PINNED=true',
    );
    expect(AppConfig.storageNamespace, old);
    expect(AppConfig.apiBaseUrl, 'https://drive.example/api');
    expect(AppConfig.backendPinned, isTrue);
  });
  test(
    'hosted pin removes stale manual LAN address and never falls back',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previous);
      // A real loopback HTTP fixture exercises the public resolver path without LAN scans.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"ok":true,"database_ok":true}');
        await request.response.close();
      });
      final url = 'http://127.0.0.1:${server.port}/api';
      dotenv.testLoad(fileInput: 'API_BASE_URL=$url\nBACKEND_PINNED=true');
      SharedPreferences.setMockInitialValues({
        'backend_manual_url': 'http://192.0.2.1:8000/api',
      });
      final resolver = BackendResolver();
      addTearDown(() {
        resolver.shutdown();
        resolver.dispose();
      });
      expect(await resolver.refresh(), url);
      expect(resolver.status, BackendStatus.connected);
      expect(resolver.source, BackendSource.environment);
      expect(resolver.manualUrl, isNull);
      await server.close(force: true);
      expect(await resolver.refresh(), url);
      expect(resolver.status, BackendStatus.unreachable);
    },
  );
}
