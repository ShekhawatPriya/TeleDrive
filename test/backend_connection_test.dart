import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/network/backend_resolver.dart';

void main() {
  test('discovery rejects a service with an unavailable database', () {
    expect(
      BackendResolver.isHealthyPayload({'ok': true, 'database_ok': true}),
      isTrue,
    );
    expect(
      BackendResolver.isHealthyPayload({'ok': false, 'database_ok': false}),
      isFalse,
    );
    expect(BackendResolver.isHealthyPayload({'ok': true}), isFalse);
    expect(BackendResolver.isHealthyPayload({'database_ok': true}), isTrue);
  });
  test(
    'automatic connection errors explain service startup instead of asking for an address',
    () {
      dotenv.testLoad(fileInput: '');
      final resolver = BackendResolver();
      final client = ApiClient(resolver);
      addTearDown(() {
        client.dio.close();
        resolver.shutdown();
        resolver.dispose();
      });
      final message = client.errorMessage(
        DioException(
          requestOptions: RequestOptions(path: '/telegram/auth/start'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(message, contains('automatically'));
      expect(message, isNot(contains('server address')));
    },
  );
}
