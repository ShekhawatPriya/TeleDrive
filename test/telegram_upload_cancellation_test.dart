import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_exceptions.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_models.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/upload-transfers');
  const events = EventChannel('test/upload-events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MethodChannelTelegramTransferService service;
  late List<MethodCall> calls;
  late Completer<Map<String, dynamic>> target;
  late Completer<Map<String, dynamic>> send;

  Future<TelegramUploadResult> upload({
    String id = 'original',
    int? chatId,
    bool derivative = false,
  }) {
    final destination = TelegramUploadTarget(
      tdlibChatId: chatId,
      telethonChannelId: 123,
    );
    if (derivative) {
      return service.uploadDerivative(
        filePath: '/fixture.jpg',
        filename: 'fixture.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 100,
        target: destination,
        transferId: id,
        variant: 'thumbnail',
      );
    }
    return service.uploadOriginal(
      filePath: '/fixture.pdf',
      filename: 'fixture.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 100,
      target: destination,
      transferId: id,
    );
  }

  Matcher cancelled() => throwsA(
    isA<TelegramClientException>().having(
      (error) => error.code,
      'code',
      'tdlib_cancelled',
    ),
  );

  setUp(() {
    calls = [];
    target = Completer<Map<String, dynamic>>();
    send = Completer<Map<String, dynamic>>();
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/upload-events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'resolveChat' => target.future,
        'sendDocument' => send.future,
        _ => null,
      };
    });
    service = MethodChannelTelegramTransferService(
      channel: channel,
      events: events,
    );
  });

  tearDown(() async {
    if (!target.isCompleted) target.complete({'tdlibChatId': -123});
    if (!send.isCompleted) send.complete({'tdlibMessageId': 100});
    service.dispose();
    await Future<void>.delayed(Duration.zero);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/upload-events'),
      null,
    );
  });

  for (final derivative in [false, true]) {
    test(
      'cancel during target lookup prevents late ${derivative ? 'derivative' : 'original'} send',
      () async {
        final pending = upload(derivative: derivative);
        final rejected = expectLater(pending, cancelled());
        await Future<void>.delayed(Duration.zero);
        expect(calls.single.method, 'resolveChat');
        await service.cancelTransfer('original');
        await rejected;
        target.complete({'tdlibChatId': -123});
        await Future<void>.delayed(Duration.zero);
        expect(calls.where((call) => call.method == 'sendDocument'), isEmpty);
      },
    );
  }

  test(
    'cancel before an already-resolved target resumes prevents send',
    () async {
      final pending = upload(chatId: -123);
      final rejected = expectLater(pending, cancelled());
      await service.cancelTransfer('original');
      await rejected;
      expect(calls.where((call) => call.method == 'sendDocument'), isEmpty);
    },
  );

  test(
    'a late target result cannot affect a new upload using the same id',
    () async {
      final first = upload();
      final rejected = expectLater(first, cancelled());
      await service.cancelTransfer('original');
      await rejected;
      final retry = upload(chatId: -456);
      target.complete({'tdlibChatId': -123});
      await Future<void>.delayed(Duration.zero);
      final sent = calls.where((call) => call.method == 'sendDocument').single;
      expect(sent.arguments['chatId'], -456);
      send.complete({'tdlibMessageId': 100, 'tdlibChatId': -456});
      expect((await retry).ref.tdlibMessageId, 100);
    },
  );

  test(
    'final native success survives a racing cancellation for durable commit',
    () async {
      final pending = upload(chatId: -123);
      await Future<void>.delayed(Duration.zero);
      expect(
        calls.where((call) => call.method == 'sendDocument'),
        hasLength(1),
      );
      await service.cancelTransfer('original');
      send.complete({'tdlibMessageId': 100, 'tdlibChatId': -123});
      expect((await pending).ref.tdlibMessageId, 100);
    },
  );

  test('native readiness cancellation remains a typed cancellation', () async {
    final pending = upload(chatId: -123);
    final rejected = expectLater(pending, cancelled());
    await Future<void>.delayed(Duration.zero);
    await service.cancelTransfer('original');
    send.completeError(
      PlatformException(
        code: 'tdlib_cancelled',
        message: 'Transfer was cancelled.',
      ),
    );
    await rejected;
  });
}
