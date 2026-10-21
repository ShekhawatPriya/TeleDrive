import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/notifications/transfer_live_activity_service.dart';
import 'package:flutter_m_fsdk/core/notifications/upload_notification_service.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_models.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_transfer_service.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/features/upload/upload_picker_helper.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gb = 1024 * 1024 * 1024;

class _Auth extends ChangeNotifier implements AuthController {
  @override
  bool get directTelegramUploadEnabled => true;
  @override
  bool get clientDerivativeGenerationEnabled => false;
  @override
  AuthUser get user =>
      const AuthUser(userId: 1, telegramId: 10, firstName: 'Test');
  @override
  String? get token => 'token';
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
  Future<void> refreshFolder(String? folderId, {bool silent = true}) async {}
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
  bool get isForeground => true;
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

/// Native transfer fake: each upload stays open until the test settles it,
/// and progress flows only to transfers someone is watching, like the bridge.
class _Telegram implements TelegramTransferService {
  _Telegram({this.premium = false});

  final bool premium;
  final sent = <String>[];
  final cancelled = <String>[];
  final results = <String, Completer<TelegramUploadResult>>{};
  final _watchers = <String, StreamController<TelegramTransferProgress>>{};

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
  Future<Map<String, dynamic>> getMe() async => {
    'id': 10,
    'is_premium': premium,
  };
  @override
  Stream<TelegramTransferProgress> watchProgress(String transferId) =>
      (_watchers[transferId] ??=
              StreamController<TelegramTransferProgress>.broadcast())
          .stream;

  void emit(String transferId, int done, int total) =>
      _watchers[transferId]?.add(
        TelegramTransferProgress(
          transferId: transferId,
          state: TelegramTransferState.uploading,
          bytesDone: done,
          totalBytes: total,
        ),
      );

  bool watched(String transferId) =>
      _watchers[transferId]?.hasListener ?? false;

  void finish(String transferId, int messageId) {
    results[transferId]!.complete(
      TelegramUploadResult(
        transferId: transferId,
        ref: TelegramMediaRef(
          variant: 'original',
          tdlibChatId: -123,
          tdlibMessageId: messageId,
        ),
        sizeBytes: 1,
        mimeType: 'video/mp4',
      ),
    );
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    cancelled.add(transferId);
    final pending = results[transferId];
    if (pending != null && !pending.isCompleted) {
      pending.completeError(Exception('cancelled'));
    }
  }

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
    return (results[transferId] = Completer<TelegramUploadResult>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UploadItem _picked(String id, {int size = 1000, String mime = 'video/mp4'}) =>
    UploadItem(
      localId: id,
      uploadClientId: 'pick-$id',
      name: '$id.mp4',
      size: size,
      mimeType: mime,
      path: '/fixture/$id',
      status: UploadStatus.selected,
      deleteLocalOnComplete: false,
    );

Future<void> _flush() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettingsController settings;
  late UploadController uploads;
  late _Telegram telegram;
  late List<RequestOptions> requests;

  Future<void> build({bool premium = false}) async {
    telegram = _Telegram(premium: premium);
    final api = ApiClient();
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          Object response = {};
          if (options.path == '/client-uploads/prepare-target') {
            response = {
              'telegramTarget': {'tdlibChatId': -123},
            };
          } else if (options.path == '/client-uploads/init') {
            final files = (options.data as Map)['files'] as List;
            response = {
              'batchId': 1,
              'files': [
                for (final (i, file) in files.indexed)
                  {
                    'localId': (file as Map)['local_id'],
                    'fileId': 100 + i,
                    'uploadJobId': 200 + i,
                  },
              ],
            };
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: response),
          );
        },
      ),
    );
    uploads = UploadController(
      api,
      _Drive(),
      settings,
      _Notifications(),
      _Auth(),
      telegram,
      liveActivity: TransferLiveActivityService.disabled,
    );
  }

  setUp(() async {
    dotenv.testLoad(
      fileInput:
          'API_BASE_URL=https://backend.example\nMAX_CONCURRENT_TELEGRAM_UPLOADS=1',
    );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = AppSettingsController();
    await settings.setUploadOnMobileData(true);
    requests = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
  });

  tearDown(() async {
    for (final pending in telegram.results.values) {
      if (!pending.isCompleted) pending.completeError(Exception('teardown'));
    }
    await _flush();
    uploads.dispose();
    settings.dispose();
  });

  test('a pick during a running upload joins the back of the queue', () async {
    await build();
    await uploads.pickWith(
      () async => UploadPickerResult(items: [_picked('video')]),
    );
    await _flush();
    expect(telegram.sent, hasLength(1));
    final session = uploads.uploadSessionId;

    var pickerOpened = false;
    await uploads.pickWith(() async {
      pickerOpened = true;
      return UploadPickerResult(items: [_picked('photo')]);
    }, folderId: '7');
    await _flush();

    expect(pickerOpened, isTrue, reason: 'pickers must open while uploading');
    expect(uploads.items.map((i) => i.localId), ['video', 'photo']);
    expect(
      uploads.items.first.status,
      UploadStatus.uploadingOriginalToTelegram,
    );
    expect(uploads.items.last.status, UploadStatus.queued);
    expect(uploads.uploadSessionId, session);
    // The running file keeps its root destination; the new one targets 7.
    expect(uploads.items.first.destinationFolderId, uploadRootFolderId);
    expect(uploads.items.last.destinationFolderId, '7');

    telegram.finish(uploads.items.first.uploadClientId, 501);
    await _flush();
    expect(uploads.items.first.status, UploadStatus.uploaded);
    expect(telegram.sent, hasLength(2));
    final prepares = requests
        .where((r) => r.path == '/client-uploads/prepare-target')
        .map((r) => (r.data as Map)['folder_id'])
        .toList();
    expect(prepares, [null, 7]);
  });

  test('a pick never re-runs items the person cancelled', () async {
    await build();
    await uploads.pickWith(
      () async => UploadPickerResult(items: [_picked('a'), _picked('b')]),
    );
    await _flush();
    await uploads.cancelItem('b');
    await _flush();
    expect(uploads.items.last.status, UploadStatus.cancelled);
    await uploads.pickWith(
      () async => UploadPickerResult(items: [_picked('c')]),
    );
    await _flush();
    expect(
      uploads.items.where((i) => i.localId == 'b').single.status,
      {UploadStatus.cancelled}.single,
    );
    expect(uploads.items.last.status, UploadStatus.queued);
  });

  test('native byte progress moves the row and reports speed', () async {
    await build();
    await uploads.pickWith(
      () async =>
          UploadPickerResult(items: [_picked('video', size: 160e6 ~/ 1)]),
    );
    await _flush();
    final transferId = uploads.items.single.uploadClientId;
    expect(
      telegram.watched(transferId),
      isTrue,
      reason: 'progress must be observed before the native send starts',
    );
    final total = uploads.items.single.size;
    expect(uploads.items.single.progress, closeTo(.03, .001));

    telegram.emit(transferId, total ~/ 2, total);
    await _flush();
    final half = uploads.items.single;
    expect(half.serverProgress, closeTo(.5, .001));
    expect(half.progress, closeTo(.03 + .5 * .89, .001));
    expect(half.transferredBytes, total ~/ 2);

    // A part restarted after a reconnect never moves the bar backwards.
    telegram.emit(transferId, total ~/ 4, total);
    await _flush();
    expect(uploads.items.single.serverProgress, closeTo(.5, .001));

    await Future<void>.delayed(const Duration(milliseconds: 520));
    telegram.emit(transferId, total * 3 ~/ 4, total);
    await _flush();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    telegram.emit(transferId, total * 7 ~/ 8, total);
    await _flush();
    expect(uploads.items.single.bytesPerSecond, greaterThan(0));
    expect(uploads.summary.progressPermille, greaterThan(800));

    telegram.finish(transferId, 900);
    await _flush();
    expect(uploads.items.single.status, UploadStatus.uploaded);
    expect(uploads.items.single.bytesPerSecond, isNull);
    expect(telegram.watched(transferId), isFalse);
  });

  test('files above 2 GB fail before any transfer on a free account', () async {
    await build();
    await uploads.pickWith(
      () async => UploadPickerResult(
        items: [
          _picked('big', size: 2 * _gb + 1),
          _picked('ok'),
        ],
      ),
    );
    await _flush();
    final big = uploads.items.first;
    expect(big.status, UploadStatus.failed);
    expect(big.error, contains('2 GB'));
    expect(big.error, contains('Telegram Premium'));
    expect(telegram.sent, [uploads.items.last.uploadClientId]);
    final init = requests.firstWhere((r) => r.path == '/client-uploads/init');
    final sentIds = ((init.data as Map)['files'] as List)
        .map((f) => (f as Map)['local_id'])
        .toList();
    expect(sentIds, ['ok']);
  });

  test('Telegram Premium accounts upload files up to 4 GB', () async {
    await build(premium: true);
    // The limit is learned from the account before the first batch starts.
    await uploads.pickWith(
      () async => UploadPickerResult(items: [_picked('warmup')]),
    );
    await _flush();
    telegram.finish(uploads.items.single.uploadClientId, 1);
    await _flush();

    await uploads.pickWith(
      () async => UploadPickerResult(
        items: [
          _picked('large', size: 3900 * 1024 * 1024),
          _picked('huge', size: 4000 * 1024 * 1024 + 1),
        ],
      ),
    );
    await _flush();
    final large = uploads.items.firstWhere((i) => i.localId == 'large');
    final huge = uploads.items.firstWhere((i) => i.localId == 'huge');
    expect(large.status, UploadStatus.uploadingOriginalToTelegram);
    expect(huge.status, UploadStatus.failed);
    expect(huge.error, contains('4 GB'));
  });

  test('a cancelled row leaves the queue after a short beat', () async {
    await build();
    await uploads.pickWith(
      () async => UploadPickerResult(items: [_picked('a'), _picked('b')]),
    );
    await _flush();
    await uploads.cancelItem('b');
    await _flush();
    expect(uploads.items.map((i) => i.localId), ['a', 'b']);
    await Future<void>.delayed(
      UploadController.cancelledRowDwell + const Duration(milliseconds: 50),
    );
    expect(uploads.items.map((i) => i.localId), ['a']);
    expect(uploads.sheetVisible, isTrue);
  });

  test('overall progress is weighted by file size', () async {
    await build();
    final items = [
      _picked('small', size: 1).copyWith(status: UploadStatus.uploaded),
      _picked('large', size: 999),
    ];
    expect(uploadOverallProgress(items), closeTo(.001, .0001));
  });
}
