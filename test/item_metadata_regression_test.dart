import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/network/api_client.dart';
import 'package:flutter_m_fsdk/core/storage/local_preferences.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/photo_date_grouping.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/justified_photo_layout.dart';
import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_m_fsdk/features/search/drive_search_controller.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

class _Repo implements DriveRepository {
  @override
  final api = ApiClient();
  final star = Completer<DriveFile>();
  final fileReads = <Completer<DriveFile>>[];
  @override
  Future<DriveFile> getFile(String id) {
    final read = Completer<DriveFile>();
    fileReads.add(read);
    return read.future;
  }

  int nextId = 10;
  @override
  Future<DriveFile> setFileStarred(String id, bool starred) => star.future;
  @override
  Future<DriveFolder> createFolder(String name, String? parentId) async =>
      DriveFolder(
        id: '${nextId++}',
        name: name,
        parentId: parentId,
        modifiedAt: '2026-09-01',
        createdAt: '2026-09-01',
      );
  @override
  Future<({List<DriveFile> files, String? nextCursor})> listFiles({
    String? folderId,
    String type = 'all',
    int limit = 60,
    String? cursor,
    bool allFolders = false,
    String? query,
  }) async => (files: [_photo('search')], nextCursor: null);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Preferences implements LocalPreferences {
  @override
  Future<Map<String, String>> recentAccess({int? userId}) async => {
    '1': '2026-09-01',
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Settings implements AppSettingsController {
  @override
  AppSettingsState get state => const AppSettingsState();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Auth implements AuthController {
  @override
  SavedAccount? get activeAccount => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

DriveFile _photo(
  String id, {
  String modified = '2026-09-01',
  bool starred = true,
  int w = 600,
  int h = 800,
}) => DriveFile(
  id: id,
  name: '$id.jpg',
  kind: FileKind.image,
  size: 100,
  modifiedAt: modified,
  createdAt: '2026-09-01',
  parentId: null,
  starred: starred,
  widthPx: w,
  heightPx: h,
  uploadStatus: 'available',
  localUri: '/fixture/$id.jpg',
);
const _folder = DriveFolder(
  id: '2',
  name: 'Folder',
  parentId: null,
  modifiedAt: '2026-09-01',
  createdAt: '2026-09-01',
  starred: true,
);

void main() {
  late _Repo repo;
  late DriveController drive;
  setUp(() async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.test/api');
    repo = _Repo();
    drive = DriveController(repo, _Preferences(), _Settings(), _Auth());
    await Future<void>.delayed(Duration.zero);
    drive.applyDriveState(
      DriveSnapshot(
        files: [_photo('1')],
        mediaFiles: [_photo('1')],
        folders: [_folder],
      ),
    );
    drive.state = drive.state.copyWith(
      starred: DriveStarredCache(
        loaded: true,
        files: [_photo('1')],
        folders: [_folder],
      ),
    );
  });
  tearDown(() {
    drive.dispose();
    repo.api.dio.close();
  });

  test(
    'share and unshare update root, gallery, starred, resolved and recents',
    () {
      drive.cacheSearchFiles([_photo('search')]);
      final before = drive.recentsSnapshot();
      drive.markShared(fileIds: {'1', 'search'}, folderIds: {'2'});
      expect(drive.folderViewSnapshot(null).folders.single.shared, isTrue);
      expect(drive.folder('2')!.shared, isTrue);
      expect(drive.state.starred.folders.single.shared, isTrue);
      expect(drive.state.starred.files.single.shared, isTrue);
      expect(drive.photoFiles('all').single.shared, isTrue);
      expect(drive.anyFile('search')!.shared, isTrue);
      expect(drive.recentsSnapshot(), isNot(before));
      drive.markUnshared(fileIds: {'1', 'search'}, folderIds: {'2'});
      expect(drive.folderViewSnapshot(null).folders.single.shared, isFalse);
      expect(drive.photoFiles('all').single.shared, isFalse);
      expect(drive.state.starred.files.single.shared, isFalse);
      expect(drive.anyFile('search')!.shared, isFalse);
    },
  );

  test(
    'star response changes only star; concurrent share and original dates survive',
    () async {
      final before = drive.file('1')!;
      final pending = drive.toggleStar('1');
      drive.markShared(fileIds: {'1'});
      repo.star.complete(_photo('1', modified: '2026-09-20', starred: false));
      await pending;
      final after = drive.file('1')!;
      expect(after.starred, isFalse);
      expect(after.shared, isTrue);
      expect(after.createdAt, before.createdAt);
      expect(after.modifiedAt, before.modifiedAt);
      expect(after.localUri, before.localUri);
      expect(
        groupByDate([after]).single.label,
        groupByDate([before]).single.label,
      );
      // A refresh with a new metadata revision still groups by the upload date.
      expect(
        groupByDate([_photo('1', modified: '2026-09-20')]).single.label,
        groupByDate([before]).single.label,
      );
    },
  );

  test('starred-only item retains a concurrent share during unstar', () async {
    drive.state = DriveState(
      starred: DriveStarredCache(loaded: true, files: [_photo('only-starred')]),
    );
    final pending = drive.toggleStar('only-starred');
    expect(drive.state.starred.files, isEmpty);
    drive.markShared(fileIds: {'only-starred'});
    repo.star.complete(_photo('only-starred', starred: false));
    await pending;
    expect(drive.anyFile('only-starred')!.shared, isTrue);
    expect(drive.anyFile('only-starred')!.starred, isFalse);
  });

  test('failed star rolls back only its flag and preserves sharing', () async {
    final pending = drive.toggleStar('1');
    drive.markShared(fileIds: {'1'}, folderIds: {'2'});
    repo.star.completeError(StateError('fixture failure'));
    await pending;
    expect(drive.file('1')!.starred, isTrue);
    expect(drive.file('1')!.shared, isTrue);
    expect(drive.state.starred.files.single.shared, isTrue);
    expect(drive.folderViewSnapshot(null).folders.single.shared, isTrue);
  });

  test(
    'six root folders and nested folders stay visible without local duplicates',
    () async {
      for (var i = 0; i < 6; i++) {
        await drive.createFolder('Root $i', null);
      }
      for (var i = 0; i < 4; i++) {
        await drive.createFolder('Nested $i', '2');
      }
      expect(drive.folderViewSnapshot(null).folders.length, 7);
      expect(drive.folderViewSnapshot('2').folders.length, 4);
      expect(drive.folders.where((folder) => folder.isOptimistic), isEmpty);
    },
  );

  test('search-only items get immediate share and star changes', () async {
    final search = DriveSearchController(repo, 'search', drive: drive);
    addTearDown(search.dispose);
    await search.loadMore();
    drive.markShared(fileIds: {'search'});
    expect(search.files.single.shared, isTrue);
    final pending = drive.toggleStar('search');
    repo.star.complete(_photo('search', starred: false));
    await pending;
    expect(search.files.single.starred, isFalse);
    expect(search.files.single.shared, isTrue);
  });

  test(
    'revocation reconciles the item without resetting the page or its dates',
    () async {
      drive.markShared(fileIds: {'1'});
      final before = drive.file('1')!;
      final reconcile = drive.reconcileSharedItems(
        fileIds: {'1'},
        folderIds: {},
      );
      repo.fileReads.single.complete(
        _photo('1', modified: '2026-09-20').copyWith(shared: false),
      );
      await reconcile;
      expect(drive.file('1')!.shared, isFalse);
      expect(drive.photoFiles('all').single.shared, isFalse);
      expect(drive.state.starred.files.single.shared, isFalse);
      expect(drive.file('1')!.createdAt, before.createdAt);
      expect(drive.file('1')!.modifiedAt, before.modifiedAt);
      expect(drive.folderViewSnapshot(null).loaded, isTrue);
    },
  );
  test('a late revoke read cannot overwrite a newer share', () async {
    final reconcile = drive.reconcileSharedItems(fileIds: {'1'}, folderIds: {});
    drive.markShared(fileIds: {'1'});
    repo.fileReads.single.complete(_photo('1').copyWith(shared: false));
    await reconcile;
    expect(drive.file('1')!.shared, isTrue);
  });
  test('revoke reconciliation cannot repopulate a switched account', () async {
    final reconcile = drive.reconcileSharedItems(fileIds: {'1'}, folderIds: {});
    await drive.resetForAccountSwitch();
    repo.fileReads.single.complete(_photo('1').copyWith(shared: true));
    await reconcile;
    expect(drive.files, isEmpty);
    expect(drive.mediaFiles, isEmpty);
  });

  test('justified layout respects each aspect ratio, width and chronology', () {
    final photos = List.generate(
      100,
      (i) =>
          _photo('$i', w: i % 3 == 0 ? 1800 : 600, h: i % 3 == 1 ? 1200 : 800),
    );
    for (final width in [280.0, 350.0, 800.0]) {
      final rows = justifyPhotos(
        photos,
        width: width,
        targetHeight: 130,
        gap: 4,
      );
      expect(
        rows.expand((row) => row.files).map((file) => file.id),
        photos.map((file) => file.id),
      );
      for (final row in rows) {
        expect(
          row.widths.reduce((a, b) => a + b) + 4 * (row.files.length - 1),
          lessThanOrEqualTo(width + .001),
        );
        for (var i = 0; i < row.files.length; i++) {
          expect(
            row.widths[i] / row.height,
            closeTo(row.files[i].widthPx! / row.files[i].heightPx!, .001),
          );
        }
      }
    }
  });
}
