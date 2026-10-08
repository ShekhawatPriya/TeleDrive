import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';

const _challengeToken = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'),
  );

  test('OTP and password requests carry their login challenge', () async {
    final api = ApiClient();
    addTearDown(() => api.dio.close());
    final requests = <RequestOptions>[];
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: options.path.endsWith('/start')
                  ? {
                      'attempt_id': 42,
                      'attempt_token': _challengeToken,
                      'status': 'code_sent',
                    }
                  : {'status': 'requires_2fa'},
            ),
          );
        },
      ),
    );
    final repository = AuthRepository(api, SecureStorageService());
    final challenge = await repository.start('+911234567890');
    final attemptId = challenge['attempt_id'] as int;
    final attemptToken = challenge['attempt_token'] as String;
    await repository.verifyCode(attemptId, attemptToken, '12345');
    await repository.verifyPassword(
      attemptId,
      attemptToken,
      'fixture-password',
    );

    expect(requests.map((request) => request.path), [
      '/telegram/auth/start',
      '/telegram/auth/verify-code',
      '/telegram/auth/verify-password',
    ]);
    expect(requests[1].data, {
      'attempt_id': 42,
      'attempt_token': _challengeToken,
      'code': '12345',
    });
    expect(requests[2].data, {
      'attempt_id': 42,
      'attempt_token': _challengeToken,
      'password': 'fixture-password',
    });
  });

  for (final invalidToken in [null, '', 'short', 'a' * 42, '!' * 43]) {
    test(
      'start rejects an absent or invalid challenge: $invalidToken',
      () async {
        final api = ApiClient();
        addTearDown(() => api.dio.close());
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'attempt_id': 42, 'attempt_token': invalidToken},
              ),
            ),
          ),
        );
        final repository = AuthRepository(api, SecureStorageService());
        await expectLater(repository.start('+911234567890'), throwsException);
      },
    );
  }
}
