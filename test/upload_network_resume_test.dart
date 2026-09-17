import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/notifications/upload_notification_service.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_transfer_service.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends ChangeNotifier implements AuthController {
  @override
  bool get directTelegramUploadEnabled => true;
  @override
  AuthUser get user =>
      const AuthUser(userId: 1, telegramId: 10, firstName: 'Test');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState get state => const DriveState();
  @override
  void syncOptimisticUploads(List<DriveFile> files) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications implements UploadNotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Telegram implements TelegramTransferService {
  @override
  Future<bool> get isAvailable async => true;
  @override
  Future<bool> get isAuthorized async => true;
  @override
  Future<void> configure({
    required String backendUserId,
    required int telegramUserId,
  }) async {}
  @override
  Future<Map<String, dynamic>> getMe() async => {'id': 10};
  @override
  Future<void> cancelTransfer(String transferId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettingsController settings;
  late UploadController uploads;
  late List<String> network;
  Completer<List<String>>? connectivityGate;
  late List<RequestOptions> requests;

  setUp(() async {
    dotenv.testLoad(fileInput: '');
    SharedPreferences.setMockInitialValues({});
    settings = AppSettingsController();
    await settings.setUploadOnMobileData(false);
    network = ['mobile'];
    connectivityGate = null;
    requests = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async =>
          connectivityGate == null ? network : await connectivityGate!.future,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    final api = ApiClient();
    // Hold at the metadata boundary. No live server or Telegram file transfer.
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
        },
      ),
    );
    uploads =
        UploadController(
            api,
            _Drive(),
            settings,
            _Notifications(),
            _Auth(),
            _Telegram(),
          )
          ..sheetVisible = true
          ..items = [
            UploadItem(
              status: UploadStatus.selected,
              localId: 'one',
              uploadClientId: 'original-id',
              name: 'one.pdf',
              size: 100,
              mimeType: 'application/pdf',
              path: '/fixture',
            ),
          ];
  });
  tearDown(() {
    uploads.dispose();
    settings.dispose();
  });

  test(
    'mobile-data action resumes the existing waiting item exactly once',
    () async {
      await uploads.confirmUpload();
      await _flush();
      expect(uploads.items.single.status, UploadStatus.waitingForWifi);
      expect(requests, isEmpty);
      final transferId = uploads.items.single.uploadClientId;
      await Future.wait([
        uploads.enableMobileDataUploads(),
        uploads.enableMobileDataUploads(),
      ]);
      await _flush();
      expect(uploads.items.single.status, UploadStatus.preparingMetadata);
      expect(uploads.items.single.uploadClientId, transferId);
      expect(requests.map((r) => r.path), ['/client-uploads/prepare-target']);
    },
  );

  test(
    'changing mobile-data permission in Settings wakes waiting uploads',
    () async {
      await uploads.confirmUpload();
      await _flush();
      expect(uploads.waitingForWifi, isTrue);
      await settings.setUploadOnMobileData(true);
      await _flush();
      expect(uploads.waitingForWifi, isFalse);
      expect(requests, hasLength(1));
    },
  );

  test(
    'permission changed during connectivity lookup cannot leave queue waiting',
    () async {
      connectivityGate = Completer<List<String>>();
      await uploads.confirmUpload();
      await _flush();
      await uploads.enableMobileDataUploads();
      connectivityGate!.complete(['mobile']);
      await _flush();
      expect(uploads.waitingForWifi, isFalse);
      expect(requests, hasLength(1));
    },
  );

  test(
    'cancelled waiting files stay cancelled when permission changes',
    () async {
      await uploads.confirmUpload();
      await _flush();
      await uploads.cancelItem('one');
      await uploads.enableMobileDataUploads();
      await _flush();
      expect(uploads.items.single.status, UploadStatus.cancelled);
      expect(requests, isEmpty);
    },
  );

  test('Wi-Fi takes precedence when both interfaces are reported', () async {
    network = ['mobile', 'wifi'];
    await uploads.confirmUpload();
    await _flush();
    expect(uploads.waitingForWifi, isFalse);
    expect(requests, hasLength(1));
  });
}
