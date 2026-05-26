import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSecureStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('AuthController pending account transaction', () {
    test('beginPendingAccountAuthorization captures candidate fields', () {
      final controller = AuthController(
        _FakeAuthRepository(),
        _FakeSecureStorage(),
      );
      controller.beginPendingAccountAuthorization(
        mode: PendingTdlibMode.normalLogin,
        candidateUserId: 0,
        candidateTelegramId: 0,
        candidatePhone: '+911111111111',
        returnTo: '/drive',
      );

      expect(controller.pendingTdlibMode, PendingTdlibMode.normalLogin);
      expect(controller.pendingPreviousUserId, isNull);
      expect(controller.pendingCandidatePhone, '+911111111111');
      expect(controller.pendingReturnTo, '/drive');
      expect(controller.pendingCandidateUserId, isNull);
      expect(controller.pendingCandidateTelegramId, isNull);
    });

    test(
      'updatePendingAccountCandidate fills in user/telegram ids after login',
      () {
        final controller = AuthController(
          _FakeAuthRepository(),
          _FakeSecureStorage(),
        );
        controller.beginPendingAccountAuthorization(
          mode: PendingTdlibMode.addAccount,
          candidateUserId: 0,
          candidateTelegramId: 0,
          candidatePhone: '+911111111111',
          returnTo: null,
        );
        controller.updatePendingAccountCandidate(
          candidateUserId: 42,
          candidateTelegramId: 999,
        );

        expect(controller.pendingCandidateUserId, 42);
        expect(controller.pendingCandidateTelegramId, 999);
      },
    );

    test('commitPendingAccountAuthorization clears the transaction', () {
      final controller = AuthController(
        _FakeAuthRepository(),
        _FakeSecureStorage(),
      );
      controller.beginPendingAccountAuthorization(
        mode: PendingTdlibMode.normalLogin,
        candidateUserId: 7,
        candidateTelegramId: 77,
        candidatePhone: '+911111111111',
        returnTo: '/photos',
      );

      final destination = controller.commitPendingAccountAuthorization();

      expect(destination, '/photos');
      expect(controller.pendingTdlibMode, isNull);
      expect(controller.pendingCandidateUserId, isNull);
      expect(controller.pendingReturnTo, isNull);
    });

    test(
      'commitPendingAccountAuthorization returns /drive when returnTo is unsafe',
      () {
        final controller = AuthController(
          _FakeAuthRepository(),
          _FakeSecureStorage(),
        );
        controller.beginPendingAccountAuthorization(
          mode: PendingTdlibMode.normalLogin,
          candidateUserId: 7,
          candidateTelegramId: 77,
          candidatePhone: '+911111111111',
          returnTo: '/tdlib-session',
        );

        final destination = controller.commitPendingAccountAuthorization();
        expect(destination, '/drive');
      },
    );
  });

  group('AuthController ephemeral cloud passwords', () {
    test('rememberEphemeralTelegramCloudPassword keys by telegramUserId', () {
      final controller = AuthController(
        _FakeAuthRepository(),
        _FakeSecureStorage(),
      );
      controller.rememberEphemeralTelegramCloudPassword(101, 'alpha');
      controller.rememberEphemeralTelegramCloudPassword(202, 'beta');

      expect(controller.takeEphemeralTelegramCloudPassword(101), 'alpha');
      // taking removes
      expect(controller.takeEphemeralTelegramCloudPassword(101), isNull);
      expect(controller.takeEphemeralTelegramCloudPassword(202), 'beta');
    });

    test(
      'clearEphemeralTelegramCloudPassword without args clears all entries',
      () {
        final controller = AuthController(
          _FakeAuthRepository(),
          _FakeSecureStorage(),
        );
        controller.rememberEphemeralTelegramCloudPassword(1, 'a');
        controller.rememberEphemeralTelegramCloudPassword(2, 'b');
        controller.clearEphemeralTelegramCloudPassword();
        expect(controller.takeEphemeralTelegramCloudPassword(1), isNull);
        expect(controller.takeEphemeralTelegramCloudPassword(2), isNull);
      },
    );

    test(
      'clearEphemeralTelegramCloudPassword with telegramUserId only clears that key',
      () {
        final controller = AuthController(
          _FakeAuthRepository(),
          _FakeSecureStorage(),
        );
        controller.rememberEphemeralTelegramCloudPassword(1, 'a');
        controller.rememberEphemeralTelegramCloudPassword(2, 'b');
        controller.clearEphemeralTelegramCloudPassword(telegramUserId: 1);
        expect(controller.takeEphemeralTelegramCloudPassword(1), isNull);
        expect(controller.takeEphemeralTelegramCloudPassword(2), 'b');
      },
    );

    test('rememberEphemeralTelegramCloudPassword ignores zero telegram id', () {
      final controller = AuthController(
        _FakeAuthRepository(),
        _FakeSecureStorage(),
      );
      controller.rememberEphemeralTelegramCloudPassword(0, 'value');
      expect(controller.takeEphemeralTelegramCloudPassword(0), isNull);
    });
  });
}
