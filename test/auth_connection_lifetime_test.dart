import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/backend_resolver.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';

class _Resolver extends BackendResolver {
  void connectionChanged() => notifyListeners();
}

class _Storage extends SecureStorageService {
  @override
  Future<AccountVault> readAccountVault() async => const AccountVault.empty();
  @override
  Future<String?> readToken() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'),
  );

  test(
    'connection notifications retain API credentials and the auth instance',
    () async {
      final resolver = _Resolver();
      final container = ProviderContainer(
        overrides: [
          backendResolverProvider.overrideWith((_) => resolver),
          secureStorageProvider.overrideWithValue(_Storage()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(resolver.shutdown);
      final auth = container.read(authControllerProvider);
      final api = container.read(apiClientProvider);
      await Future<void>.delayed(Duration.zero);
      auth.user = const AuthUser(
        userId: 1,
        telegramId: 42,
        firstName: 'Fixture',
      );
      auth.token = 'fixture-session';
      api.setToken('fixture-session');
      auth.beginPendingAccountAuthorization(
        mode: PendingTdlibMode.normalLogin,
        candidateUserId: 1,
        candidateTelegramId: 42,
        candidatePhone: '+10000000000',
      );
      resolver.connectionChanged();
      await container.pump();
      expect(
        identical(container.read(apiClientProvider), api),
        isTrue,
        reason:
            'A connectivity update must not replace the authenticated API client.',
      );
      expect(
        identical(container.read(authControllerProvider), auth),
        isTrue,
        reason:
            'The router and login screen must keep observing the same auth controller.',
      );
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      expect(
        api.dio.options.headers['Authorization'],
        'Bearer fixture-session',
      );
    },
  );
}
