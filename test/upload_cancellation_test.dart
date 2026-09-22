import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/notifications/upload_notification_service.dart';
import 'package:flutter_m_fsdk/core/telegram/pending_telegram_commit_queue.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_exceptions.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_models.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_transfer_service.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends ChangeNotifier implements AuthController {
  @override
  bool get directTelegramUploadEnabled => true;
  @override
  bool get clientDerivativeGenerationEnabled => true;
  @override
  AuthUser get user =>
      const AuthUser(userId: 1, telegramId: 10, firstName: 'Test');
  @override
  Future<void> refreshPendingDirectCommitCount() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState get state => const DriveState();
  @override
  void syncOptimisticUploads(List<DriveFile> files) {}
  @override
  Future<void> refresh({bool silent = false, bool force = false}) async {}
  @override
  void bumpFolderAggregates(
    String? folderId, {
    required int fileCountDelta,
    required int sizeDelta,
  }) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications implements UploadNotificationService {
  @override
  Future<void> showUploadComplete({
    required int total,
    required int failed,
  }) async {}
  @override
  Future<void> showUploadFailed({required int failed}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Telegram implements TelegramTransferService {
  final sent = <String>[];
  final cancelled = <String>[];
  final result = Completer<TelegramUploadResult>();
  Completer<bool>? available;
  @override
  Future<bool> get isAvailable async =>
      available == null ? true : available!.future;
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
  Future<void> cancelTransfer(String transferId) async =>
      cancelled.add(transferId);
  @override
  Future<TelegramUploadResult> uploadOriginal({
    required String filePath,
    required String filename,
    required String mimeType,
    required int sizeBytes,
    required TelegramUploadTarget target,
    String? transferId,
  }) {
    sent.add(transferId!);
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _flush() async {
  for (var i = 0; i < 35; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettingsController settings;
  late UploadController uploads;
  late _Telegram telegram;
  late List<RequestOptions> requests;
  late Map<String, Completer<void>> gates;
  late List<PendingTelegramCommit> recordsAtCompletion;
  const startedPath = '/client-uploads/1/file-started';
  const completePath = '/client-uploads/1/file-complete';
  const cancelPath = '/upload-jobs/3/cancel';

  setUp(() async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://backend.example');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = AppSettingsController();
    await settings.setUploadOnMobileData(true);
    requests = [];
    gates = {};
    recordsAtCompletion = [];
    telegram = _Telegram();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    final api = ApiClient();
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          await gates[options.path]?.future;
          final Object response;
          switch (options.path) {
            case '/client-uploads/prepare-target':
              response = {
                'telegramTarget': {'tdlibChatId': -123},
              };
            case '/client-uploads/init':
              response = {
                'batchId': 1,
                'files': [
                  {
                    'localId': 'one',
                    'fileId': 2,
                    'uploadJobId': 3,
                    'serverPolicy': {
                      'requiresThumbnail': true,
                      'requiresPreview': true,
                    },
                  },
                ],
              };
            case completePath:
              final queue = PendingTelegramCommitQueue();
              recordsAtCompletion = await queue.list(
                queue.activeScope(backendUserId: 1, telegramUserId: 10),
              );
              response = {};
            default:
              response = {};
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: response),
          );
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
            telegram,
          )
          ..sheetVisible = true
          ..items = [
            UploadItem(
              localId: 'one',
              uploadClientId: 'initial-id',
              name: 'one.jpg',
              size: 100,
              mimeType: 'image/jpeg',
              path: '/fixture.jpg',
              status: UploadStatus.selected,
              deleteLocalOnComplete: false,
            ),
          ];
  });

  tearDown(() async {
    for (final gate in gates.values) {
      if (!gate.isCompleted) gate.complete();
    }
    if (!telegram.result.isCompleted) {
      telegram.result.complete(
        const TelegramUploadResult(
          transferId: 'fixture',
          ref: TelegramMediaRef(
            variant: 'original',
            tdlibChatId: -123,
            tdlibMessageId: 100,
          ),
          sizeBytes: 100,
          mimeType: 'image/jpeg',
        ),
      );
    }
    await _flush();
    uploads.dispose();
    settings.dispose();
  });

  test(
    'cancel during file-started prevents upload and releases reservation only after response',
    () async {
      gates[startedPath] = Completer<void>();
      await uploads.confirmUpload();
      await _flush();
      expect(requests.last.path, startedPath);
      final id = uploads.items.single.uploadClientId;
      await uploads.cancelItem('one');
      await uploads.confirmUpload();
      expect(uploads.items.single.status, UploadStatus.cancelling);
      expect(uploads.hasBlockingUploads, isTrue);
      expect(uploads.items.single.uploadClientId, id);
      expect(telegram.cancelled, [id, '$id:thumbnail', '$id:preview']);
      expect(requests.where((r) => r.path == cancelPath), isEmpty);
      gates[startedPath]!.complete();
      await _flush();
      expect(telegram.sent, isEmpty);
      expect(uploads.items.single.status, UploadStatus.cancelled);
      expect(uploads.hasBlockingUploads, isFalse);
      expect(requests.where((r) => r.path == cancelPath), hasLength(1));
      expect(requests.where((r) => r.path.endsWith('file-failed')), isEmpty);
    },
  );

  test('cancelled readiness failure cannot resurrect the upload', () async {
    telegram.available = Completer<bool>();
    await uploads.confirmUpload();
    await uploads.cancelItem('one');
    telegram.available!.complete(false);
    await _flush();
    expect(uploads.items.single.status, UploadStatus.cancelled);
    expect(uploads.hasBlockingUploads, isFalse);
    expect(requests, isEmpty);
    expect(telegram.sent, isEmpty);
  });

  test(
    'cancel during batch init records returned ids and cancels metadata without upload',
    () async {
      gates['/client-uploads/init'] = Completer<void>();
      await uploads.confirmUpload();
      await _flush();
      await uploads.cancelItem('one');
      gates['/client-uploads/init']!.complete();
      await _flush();
      expect(uploads.items.single.status, UploadStatus.cancelled);
      expect(telegram.sent, isEmpty);
      expect(requests.where((r) => r.path == startedPath), isEmpty);
      expect(requests.where((r) => r.path == cancelPath), hasLength(1));
    },
  );

  test(
    'native cancellation failure cancels metadata after native work settles',
    () async {
      await uploads.confirmUpload();
      await _flush();
      expect(telegram.sent, hasLength(1));
      await uploads.cancelItem('one');
      expect(requests.where((r) => r.path == cancelPath), isEmpty);
      telegram.result.completeError(
        const TelegramClientException('Cancelled', code: 'tdlib_cancelled'),
      );
      await _flush();
      expect(uploads.items.single.status, UploadStatus.cancelled);
      expect(uploads.hasBlockingUploads, isFalse);
      expect(requests.where((r) => r.path == cancelPath), hasLength(1));
    },
  );

  test(
    'final original after cancel is persisted before commit and never cancels backend slot',
    () async {
      gates[completePath] = Completer<void>();
      await uploads.confirmUpload();
      await _flush();
      await uploads.cancelItem('one');
      telegram.result.complete(
        TelegramUploadResult(
          transferId: telegram.sent.single,
          ref: const TelegramMediaRef(
            variant: 'original',
            tdlibChatId: -123,
            tdlibMessageId: 100,
          ),
          sizeBytes: 100,
          mimeType: 'image/jpeg',
        ),
      );
      await _flush();
      expect(uploads.items.single.status, UploadStatus.committingMetadata);
      expect(uploads.hasBlockingUploads, isTrue);
      expect(requests.where((r) => r.path == cancelPath), isEmpty);
      final queue = PendingTelegramCommitQueue();
      expect(await queue.pendingCount(backendUserId: 1, telegramUserId: 10), 1);
      gates[completePath]!.complete();
      await _flush();
      expect(
        recordsAtCompletion.single.payload['original']['tdlib_message_id'],
        '100',
      );
      expect(uploads.items.single.status, UploadStatus.uploaded);
      expect(uploads.hasBlockingUploads, isFalse);
      expect(await queue.pendingCount(backendUserId: 1, telegramUserId: 10), 0);
      expect(requests.where((r) => r.path == cancelPath), isEmpty);
    },
  );
}
