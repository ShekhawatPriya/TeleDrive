import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/secure_storage.dart';
import 'package:flutter_m_fsdk/features/auth/auth_repository.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/profile/storage_summary_controller.dart';
import 'package:flutter_m_fsdk/features/search/drive_search_controller.dart';
import 'package:flutter_m_fsdk/features/share/share_controller.dart';
import 'package:flutter_m_fsdk/features/share/share_repository.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/models/share_models.dart';

class _Storage implements SecureStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState state = const DriveState();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Shares implements ShareRepository {
  final requests = <Completer<List<Share>>>[];
  final revocations = <String, Completer<void>>{};
  @override
  Future<List<Share>> listShares() {
    final request = Completer<List<Share>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> revokeShare(String id) =>
      (revocations[id] = Completer<void>()).future;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Summary implements StorageSummaryRepository {
  final requests = <Completer<StorageSummary>>[];
  @override
  Future<StorageSummary> fetch() {
    final request = Completer<StorageSummary>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SearchRepo implements DriveRepository {
  final requests = <Completer<({List<DriveFile> files, String? nextCursor})>>[];
  final cursors = <String?>[];
  @override
  Future<({List<DriveFile> files, String? nextCursor})> listFiles({
    String? folderId,
    String type = 'all',
    int limit = 60,
    String? cursor,
    bool allFolders = false,
    String? query,
  }) {
    cursors.add(cursor);
    final request = Completer<({List<DriveFile> files, String? nextCursor})>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Share _share(String id) => Share(
  id: id,
  token: 'fixture',
  url: 'https://example.test/s/$id',
  permission: SharePermission.preview,
  createdAt: DateTime(2026),
  viewCount: 0,
  downloadCount: 0,
  items: const [],
);
DriveFile _file(String id) => DriveFile(
  id: id,
  name: '$id.txt',
  kind: FileKind.text,
  size: 10,
  modifiedAt: '2026-01-01',
  createdAt: '2026-01-01',
  parentId: null,
  starred: false,
);

void main() {
  setUp(
    () => dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api'),
  );
  test(
    'candidate bootstrap never changes shared request credentials',
    () async {
      final api = ApiClient()..setToken('active-account');
      addTearDown(() => api.dio.close());
      final started = Completer<RequestOptions>();
      final finish = Completer<void>();
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            started.complete(options);
            await finish.future;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'currentUser': {
                    'id': 2,
                    'firstName': 'Candidate',
                    'telegramId': 22,
                  },
                },
              ),
            );
          },
        ),
      );
      final pending = AuthRepository(
        api,
        _Storage(),
      ).bootstrapWithToken('candidate', includeDrive: false);
      final request = await started.future;
      expect(request.headers['Authorization'], 'Bearer candidate');
      expect(api.token, 'active-account');
      expect(api.dio.options.headers['Authorization'], 'Bearer active-account');
      finish.complete();
      await pending;
      expect(api.token, 'active-account');
    },
  );

  test('late share refresh cannot repopulate a switched account', () async {
    final repo = _Shares();
    final controller = ShareController(repo, _Drive());
    addTearDown(controller.dispose);
    final old = controller.refresh();
    controller.resetForAccountSwitch();
    final current = controller.refresh();
    repo.requests[1].complete([_share('new')]);
    await current;
    repo.requests[0].complete([_share('old')]);
    await old;
    expect(controller.shares.map((s) => s.id), ['new']);
  });

  test('failed concurrent revocation restores only its own share', () async {
    final repo = _Shares();
    final controller = ShareController(repo, _Drive());
    addTearDown(controller.dispose);
    final loaded = controller.refresh();
    repo.requests.single.complete([_share('a'), _share('b')]);
    await loaded;
    final a = controller.revokeShare('a');
    final b = controller.revokeShare('b');
    repo.revocations['b']!.complete();
    await b;
    final failure = expectLater(a, throwsStateError);
    repo.revocations['a']!.completeError(StateError('offline'));
    await failure;
    expect(controller.shares.map((s) => s.id), ['a']);
  });

  test('storage responses cannot cross account reset or disposal', () async {
    final repo = _Summary();
    final container = ProviderContainer(
      overrides: [
        driveControllerProvider.overrideWith((_) => _Drive()),
        storageSummaryRepositoryProvider.overrideWithValue(repo),
      ],
    );
    final controller = container.read(storageSummaryControllerProvider);
    final old = controller.ensureLoaded();
    controller.resetForAccountSwitch();
    repo.requests.single.complete(StorageSummary.empty);
    await old;
    expect(controller.value, isNull);
    final disposed = controller.ensureLoaded();
    container.dispose();
    repo.requests.last.complete(StorageSummary.empty);
    await disposed;
  });

  test('search paginates, deduplicates and ignores refresh races', () async {
    final repo = _SearchRepo();
    final controller = DriveSearchController(repo, 'notes');
    addTearDown(controller.dispose);
    final first = controller.loadMore();
    repo.requests[0].complete((files: [_file('1')], nextCursor: 'next'));
    await first;
    final oldPage = controller.loadMore();
    expect(repo.cursors.last, 'next');
    final fresh = controller.refresh();
    repo.requests[2].complete((files: [_file('3')], nextCursor: 'more'));
    await fresh;
    repo.requests[1].complete((files: [_file('2')], nextCursor: null));
    await oldPage;
    expect(controller.files.map((f) => f.id), ['3']);
    final next = controller.loadMore();
    repo.requests[3].complete((
      files: [_file('3'), _file('4')],
      nextCursor: null,
    ));
    await next;
    expect(controller.files.map((f) => f.id), ['3', '4']);
    expect(controller.hasMore, isFalse);
  });
}
