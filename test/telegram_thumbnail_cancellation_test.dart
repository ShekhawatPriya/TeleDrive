import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_models.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_transfer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/thumbnail-transfers');
  const events = EventChannel('test/thumbnail-events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MethodChannelTelegramTransferService service;
  late List<MethodCall> calls;
  late Completer<Map<String, dynamic>> download;
  setUp(() {
    PathProviderPlatform.instance = _Paths();
    calls = [];
    download = Completer<Map<String, dynamic>>();
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/thumbnail-events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'downloadToFile') return download.future;
      return null;
    });
    service = MethodChannelTelegramTransferService(
      channel: channel,
      events: events,
    );
  });
  tearDown(() async {
    if (!download.isCompleted) download.complete({'filePath': '/unused'});
    service.dispose();
    await Future<void>.delayed(Duration.zero);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('test/thumbnail-events'),
      null,
    );
  });

  test(
    'cancellation forwards the exact native transfer id and rejects late success',
    () async {
      final token = CancelToken();
      final pending = service.downloadToCache(
        const TelegramMediaRef(variant: 'thumbnail', tdlibFileId: 1),
        filename: 'photo.jpg',
        cacheKey: 'scope:1',
        variant: 'thumbnail',
        cancelToken: token,
      );
      final result = expectLater(pending, throwsA(isA<DioException>()));
      await Future<void>.delayed(Duration.zero);
      final request = calls.singleWhere(
        (call) => call.method == 'downloadToFile',
      );
      token.cancel();
      await result;
      await Future<void>.delayed(Duration.zero);
      final cancel = calls.singleWhere(
        (call) => call.method == 'cancelTransfer',
      );
      expect(cancel.arguments['transferId'], request.arguments['transferId']);
      download.complete({'filePath': '/late'});
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('end-to-end deadline cancels native lookup/download', () async {
    final pending = service.downloadToCache(
      const TelegramMediaRef(variant: 'thumbnail', tdlibFileId: 1),
      filename: 'photo.jpg',
      cacheKey: 'scope:1',
      variant: 'thumbnail',
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(pending, throwsA(isA<TimeoutException>()));
    expect(
      calls.where((call) => call.method == 'cancelTransfer'),
      hasLength(1),
    );
  });

  test('an already cancelled request never enters the native bridge', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      service.downloadToCache(
        const TelegramMediaRef(variant: 'thumbnail', tdlibFileId: 1),
        filename: 'photo.jpg',
        cacheKey: 'scope:1',
        cancelToken: token,
      ),
      throwsA(isA<DioException>()),
    );
    expect(calls, isEmpty);
  });
}
