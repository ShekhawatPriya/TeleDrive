import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_exceptions.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_client_models.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_media_access_service.dart';
import 'package:flutter_m_fsdk/core/telegram/telegram_transfer_service.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_test/flutter_test.dart';

const photo = DriveFile(
  id: '1',
  name: 'one.jpg',
  kind: FileKind.image,
  size: 10,
  modifiedAt: 'v1',
  createdAt: '',
  parentId: null,
  starred: false,
);
const mediaRef = TelegramMediaRef(variant: 'thumbnail', tdlibFileId: 1);

class _Auth extends ChangeNotifier implements AuthController {
  @override
  AuthUser? user = const AuthUser(
    userId: 1,
    telegramId: 10,
    firstName: 'Fixture',
  );
  @override
  String? token = 'test';
  @override
  SavedAccount? get activeAccount => null;
  @override
  bool get switchingAccount => false;
  void switchTo(int id) {
    user = AuthUser(userId: id, telegramId: id * 10, firstName: 'Fixture');
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements DriveRepository {
  final gate = Completer<void>();
  int reads = 0;
  @override
  Future<({TelegramMediaRef? ref, String? fallbackUrl, String cacheKey})>
  mediaRef(
    String id, {
    String variant = 'original',
    CancelToken? cancelToken,
  }) async {
    reads++;
    await gate.future;
    return (
      ref: const TelegramMediaRef(variant: 'thumbnail', tdlibFileId: 1),
      fallbackUrl: null,
      cacheKey: 'file:1',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transfer implements TelegramTransferService {
  final configureGate = Completer<void>();
  int configurations = 0;
  int downloads = 0;
  int me = 10;
  @override
  Future<void> configure({
    required String backendUserId,
    required int telegramUserId,
  }) async {
    configurations++;
    await configureGate.future;
  }

  @override
  Future<bool> get isAuthorized async => true;
  @override
  Future<Map<String, dynamic>> getMe() async => {'id': me};
  @override
  Future<TelegramDownloadResult> downloadToCache(
    TelegramMediaRef ref, {
    required String filename,
    required String cacheKey,
    Duration? timeout,
    String? variant,
    CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    downloads++;
    return TelegramDownloadResult(file: File('/fixture'), ref: ref);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => dotenv.testLoad(fileInput: 'BACKEND_IDENTITY=test'));
  test(
    'concurrent thumbnails share setup and account changes reject metadata results',
    () async {
      final auth = _Auth();
      final repo = _Repo();
      final transfer = _Transfer();
      final service = TelegramMediaAccessService(
        driveRepository: repo,
        transferService: transfer,
        auth: auth,
      );
      addTearDown(service.dispose);
      final first = service.downloadForPrivateView(photo, variant: 'thumbnail');
      final second = service.downloadForPrivateView(
        photo,
        variant: 'thumbnail',
      );
      final expectations = [
        expectLater(first, throwsA(isA<TelegramClientUnavailableException>())),
        expectLater(second, throwsA(isA<TelegramClientUnavailableException>())),
      ];
      await flush();
      expect(transfer.configurations, 1);
      transfer.configureGate.complete();
      await flush();
      expect(repo.reads, 2);
      auth.switchTo(2);
      auth.switchTo(1); // Even an A -> B -> A round trip invalidates the reads.
      repo.gate.complete();
      await Future.wait(expectations);
      expect(transfer.downloads, 0);
    },
  );

  test(
    'a new account waits for older native configuration to finish',
    () async {
      final auth = _Auth();
      final repo = _Repo()..gate.complete();
      final transfer = _Transfer();
      final service = TelegramMediaAccessService(
        driveRepository: repo,
        transferService: transfer,
        auth: auth,
      );
      addTearDown(service.dispose);
      final old = service.downloadForPrivateView(photo, variant: 'thumbnail');
      final rejected = expectLater(
        old,
        throwsA(isA<TelegramClientUnavailableException>()),
      );
      await flush();
      auth.switchTo(2);
      transfer.me = 20;
      final current = service.downloadForPrivateView(
        photo,
        variant: 'thumbnail',
      );
      await flush();
      expect(transfer.configurations, 1);
      transfer.configureGate.complete();
      await rejected;
      expect(await current, isNotNull);
      expect(transfer.configurations, 2);
      expect(transfer.downloads, 1);
    },
  );

  test(
    'a mismatched local Telegram identity fails before metadata access',
    () async {
      final repo = _Repo();
      final transfer = _Transfer()..me = 999;
      transfer.configureGate.complete();
      final service = TelegramMediaAccessService(
        driveRepository: repo,
        transferService: transfer,
        auth: _Auth(),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.downloadForPrivateView(photo),
        throwsA(isA<TelegramAccountMismatchException>()),
      );
      expect(repo.reads, 0);
      expect(transfer.downloads, 0);
    },
  );
}
