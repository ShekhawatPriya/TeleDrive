import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/network/backend_resolver.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Resolver extends BackendResolver {
  String address = 'https://backend.example.test/api';
  BackendSource selectedSource = BackendSource.environment;
  @override
  String get baseUrl => address;
  @override
  BackendSource get source => selectedSource;
  @override
  BackendStatus get status => BackendStatus.connected;
  @override
  Future<void> ensureResolved() async {}
  @override
  Future<void> recheckIfUnreachable() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Resolver resolver;
  late ApiClient api;
  late _Adapter adapter;
  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://backend.example.test/api');
    resolver = _Resolver();
    api = ApiClient(resolver);
    adapter = _Adapter();
    api.dio.httpClientAdapter = adapter;
  });
  tearDown(() {
    api.dio.close();
    resolver.shutdown();
    resolver.dispose();
  });

  test(
    'foreign media origin never receives bearer or query credentials',
    () async {
      api.setToken('fixture-token');
      await expectLater(
        api.dio.get('https://media.example.test/file?token=fixture-token'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'same-origin downloads keep authentication and refuse redirects',
    () async {
      api.setToken('fixture-token');
      await api.dio.get('https://backend.example.test/api/files/1/download');
      final request = adapter.requests.single;
      expect(request.headers['Authorization'], 'Bearer fixture-token');
      expect(request.followRedirects, isFalse);
    },
  );

  for (final source in [
    BackendSource.discovered,
    BackendSource.scanned,
    BackendSource.cached,
  ]) {
    test('$source cannot receive saved bearer or login secrets', () async {
      resolver.selectedSource = source;
      resolver.address = 'http://192.0.2.10:8000/api';
      await expectLater(
        api.dio.get(
          '/frontend/bootstrap',
          options: Options(
            headers: {'Authorization': 'Bearer fixture-restored-token'},
          ),
        ),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        api.dio.post('/telegram/auth/start', data: {'phone_number': 'fixture'}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
    });
  }

  test('active bearer stays bound after resolver changes authority', () async {
    api.setToken('fixture-token');
    resolver.selectedSource = BackendSource.manual;
    resolver.address = 'https://different.example.test/api';
    await expectLater(api.dio.get('/me'), throwsA(isA<DioException>()));
    expect(() => api.mediaUrl('/me/photo'), throwsStateError);
    expect(adapter.requests, isEmpty);
  });

  test(
    'Android emulator alias cannot implicitly authorize a physical LAN host',
    () async {
      resolver.selectedSource = BackendSource.sameMachine;
      resolver.address = 'http://10.0.2.2:8000/api';
      await expectLater(
        api.dio.post('/telegram/auth/start', data: {'phone_number': 'fixture'}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'loopback also needs explicit trust before sending credentials',
    () async {
      resolver.selectedSource = BackendSource.sameMachine;
      resolver.address = 'http://127.0.0.1:8000/api';
      await expectLater(
        api.dio.post('/telegram/auth/start', data: {'phone_number': 'fixture'}),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
      resolver.selectedSource = BackendSource.manual;
      await api.dio.post(
        '/telegram/auth/start',
        data: {'phone_number': 'fixture'},
      );
      expect(adapter.requests.single.uri.host, '127.0.0.1');
    },
  );

  test(
    'explicit backend accepts a new login without active credentials',
    () async {
      resolver.selectedSource = BackendSource.manual;
      resolver.address = 'https://selected.example.test/api';
      await api.dio.post(
        '/telegram/auth/start',
        data: {'phone_number': 'fixture'},
      );
      expect(adapter.requests.single.uri.host, 'selected.example.test');
    },
  );

  test('new tokenized media URLs are refused after untrusted discovery', () {
    api.setToken('fixture-token');
    resolver.selectedSource = BackendSource.discovered;
    resolver.address = 'http://192.0.2.10:8000/api';
    expect(() => api.mediaUrl('/files/1/preview'), throwsStateError);
  });

  test(
    'manual address must use an HTTP origin without embedded credentials',
    () {
      for (final value in [
        'file:///etc/test',
        'https://user:pass@example.test/api',
      ]) {
        expect(
          () => BackendResolver.normalizeBackendUrl(value),
          throwsFormatException,
        );
      }
    },
  );
}
