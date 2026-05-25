import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/features/profile/widgets/switch_account_provider.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeSecureStorage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAuthController extends AuthController {
  MockAuthController() : super(FakeAuthRepository(), FakeSecureStorage());
}

class MockUploadController extends ChangeNotifier implements UploadController {
  MockUploadController({required this.mockHasBlockingUploads});

  final bool mockHasBlockingUploads;

  @override
  bool get hasBlockingUploads => mockHasBlockingUploads;

  @override
  List<UploadItem> get items => [];

  @override
  bool get uploading => mockHasBlockingUploads;

  @override
  int get activeCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('checkUploadsBlocked blocks account switch when active uploads exist', (tester) async {
    final mockAuth = MockAuthController();
    final mockUpload = MockUploadController(mockHasBlockingUploads: true);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => mockAuth),
        uploadControllerProvider.overrideWith((ref) => mockUpload),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(switchAccountProvider.notifier);

    // Pump a widget with a Navigator so showDialog works
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  final blocked = notifier.checkUploadsBlocked(context);
                  expect(blocked, isTrue);
                },
                child: const Text('Check'),
              );
            },
          ),
        ),
      ),
    );

    // Tap the button and trigger dialog showing
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    // Verify dialog is shown
    expect(find.text('Upload in Progress'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);

    // Dismiss the dialog
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Upload in Progress'), findsNothing);
  });

  testWidgets('checkUploadsBlocked returns true and fallbacks to toast if context has no Navigator', (tester) async {
    final mockAuth = MockAuthController();
    final mockUpload = MockUploadController(mockHasBlockingUploads: true);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => mockAuth),
        uploadControllerProvider.overrideWith((ref) => mockUpload),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(switchAccountProvider.notifier);

    // Build a context with NO Navigator ancestor
    await tester.pumpWidget(
      const ColoredBox(color: Colors.red),
    );
    final context = tester.element(find.byType(ColoredBox));

    // Call checkUploadsBlocked which will throw synchronous error due to lack of Navigator.
    // Our try-catch should catch it, show premium toast fallback, and return true.
    final blocked = notifier.checkUploadsBlocked(context);
    expect(blocked, isTrue);
  });

  test('checkUploadsBlocked returns false when no blocking uploads exist', () {
    final mockAuth = MockAuthController();
    final mockUpload = MockUploadController(mockHasBlockingUploads: false);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => mockAuth),
        uploadControllerProvider.overrideWith((ref) => mockUpload),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(switchAccountProvider.notifier);
    
    // Pass a dummy BuildContext (can use a simple mock/fake or no-op/null context if it returns false without checking context)
    // Since hasBlockingUploads is false, it returns false immediately without checking the context.
    final blocked = notifier.checkUploadsBlocked(FakeBuildContext());
    expect(blocked, isFalse);
  });
}

class FakeBuildContext extends Fake implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
