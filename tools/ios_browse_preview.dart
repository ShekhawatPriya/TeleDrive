// Simulator-only fixture for the iOS browsing surfaces: Drive home, folders,
// Starred, Shared and the Archive, Locked and Trash spaces, inside the real
// shell with its native tab bar. Production builds use lib/main.dart.
//
//   flutter run -t tools/ios_browse_preview.dart \
//     --dart-define=PHOTO_PREVIEW_PATH=$PWD/test/fixtures/design/alpine.jpg
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_m_fsdk/core/navigation/recovery_page.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/drive/drive_screen.dart';
import 'package:flutter_m_fsdk/features/drive/folder_screen.dart';
import 'package:flutter_m_fsdk/features/drive/starred_screen.dart';
import 'package:flutter_m_fsdk/features/profile/archive_screen.dart';
import 'package:flutter_m_fsdk/features/profile/gallery_backup_controller.dart';
import 'package:flutter_m_fsdk/features/profile/locked_screen.dart';
import 'package:flutter_m_fsdk/features/photos/photos_screen.dart';
import 'package:flutter_m_fsdk/features/profile/trash_screen.dart';
import 'package:flutter_m_fsdk/features/search/drive_search_controller.dart';
import 'package:flutter_m_fsdk/features/share/my_shares_screen.dart';
import 'package:flutter_m_fsdk/features/share/share_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/main_shell.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/models/share_models.dart';
import 'package:flutter_m_fsdk/widgets/ios/ios_accessibility.dart';
import 'package:flutter_m_fsdk/widgets/search_keyboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _photo = String.fromEnvironment('PHOTO_PREVIEW_PATH');

DriveFile _file(
  String id,
  String name,
  FileKind kind,
  int size, {
  bool starred = false,
  bool shared = false,
  bool image = false,
}) => DriveFile(
  id: id,
  name: name,
  kind: kind,
  size: size,
  createdAt: '2026-09-14',
  modifiedAt: '2026-09-14',
  parentId: null,
  starred: starred,
  shared: shared,
  thumbnailUrl: image && _photo.isNotEmpty ? _photo : null,
  uploadStatus: 'available',
);

DriveFolder _folder(
  String id,
  String name,
  int count,
  int size, {
  bool starred = false,
  bool shared = false,
}) => DriveFolder(
  id: id,
  name: name,
  parentId: null,
  createdAt: '2026-09-10',
  modifiedAt: '2026-09-10',
  starred: starred,
  shared: shared,
  recursiveFileCount: count,
  recursiveSize: size,
);

final _files = [
  _file(
    'f1',
    'A weekend in the mountains.jpg',
    FileKind.image,
    2400000,
    starred: true,
    image: true,
  ),
  _file('f2', 'Q3 board update.pdf', FileKind.pdf, 860000, shared: true),
  _file('f3', 'Alpine afternoon.jpg', FileKind.image, 2300000, image: true),
  _file('f4', 'Kayak session.mov', FileKind.video, 48000000),
  _file('f5', 'Lease agreement.docx', FileKind.doc, 120000, starred: true),
  _file('f6', 'Budget 2026.xlsx', FileKind.sheet, 64000),
  _file('f7', 'Interview notes.txt', FileKind.text, 8000),
  _file('f8', 'Road trip playlist.m4a', FileKind.audio, 6400000),
];
final _folders = [
  _folder('d1', 'Everyday essentials', 12, 40000000),
  _folder('d2', 'Places to remember', 24, 122000000, starred: true),
  _folder('d3', 'Tax documents 2026', 9, 18000000, shared: true),
  _folder('d4', 'Design references', 41, 310000000),
];

class _Auth extends ChangeNotifier implements AuthController {
  @override
  bool get isAuthenticated => false;
  @override
  AuthUser? get user => const AuthUser(
    userId: 1,
    telegramId: 123456789,
    firstName: 'Alex',
    lastName: 'Morgan',
  );
  @override
  String? get token => 'fixture';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState state = const DriveState();
  @override
  int get accountGeneration => 0;
  @override
  List<DriveFolder> get folders => _folders;
  @override
  DriveFile? file(String id) => _files.where((f) => f.id == id).firstOrNull;
  @override
  DriveFolder? folder(String id) =>
      _folders.where((f) => f.id == id).firstOrNull;
  @override
  DriveFolderViewSnapshot folderViewSnapshot(String? folderId) =>
      DriveFolderViewSnapshot(
        folderId: folderId,
        folder: folderId == null ? null : folder(folderId),
        folders: folderId == null ? _folders : _folders.take(2).toList(),
        files: _files,
        path: folderId == null
            ? const []
            : [_folder('root', 'Projects', 3, 0), folder(folderId)!],
        loaded: true,
        loading: false,
        loadingMore: false,
        hasMore: false,
        error: null,
      );
  @override
  DriveRecentsSnapshot recentsSnapshot() =>
      DriveRecentsSnapshot(_files.take(5).toList());
  @override
  DriveStarredSnapshot starredSnapshot() => DriveStarredSnapshot(
    files: _files.where((f) => f.starred).toList(),
    folders: [_folders[1], _folders[3]],
    loaded: true,
    loading: false,
    loadingMore: false,
    hasMore: false,
    error: null,
  );
  @override
  List<DriveFile> photoFiles(String filter) => [
    for (var i = 0; i < 24; i++)
      _file(
        'p$i',
        i % 5 == 3 ? 'Clip $i.mov' : 'Photo $i.jpg',
        i % 5 == 3 ? FileKind.video : FileKind.image,
        2400000,
        image: true,
      ),
  ];
  @override
  void setActiveFolderId(String? id) {}
  @override
  Future<void> markAccessed(String id) async {}
  @override
  Future<void> ensureStarredLoaded({bool force = false}) async {}
  @override
  Future<void> refresh({bool silent = false, bool force = false}) =>
      Future.delayed(const Duration(milliseconds: 600));
  @override
  Future<void> refreshFolder(String? folderId, {bool silent = true}) =>
      Future.delayed(const Duration(milliseconds: 600));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Search extends ChangeNotifier implements DriveSearchController {
  @override
  String? get error => null;
  @override
  bool get loading => false;
  @override
  bool get loaded => true;
  @override
  List<DriveFile> get files => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _shares = [
  Share(
    id: 's1',
    token: 'a',
    url: 'https://example.com/s/a',
    permission: SharePermission.preview,
    createdAt: DateTime(2026, 9, 12),
    viewCount: 28,
    downloadCount: 0,
    items: const [],
    primaryName: 'Our mountain weekend',
    primaryKind: ShareItemType.folder,
    itemCount: 12,
  ),
  Share(
    id: 's2',
    token: 'b',
    url: 'https://example.com/s/b',
    permission: SharePermission.download,
    createdAt: DateTime(2026, 9, 2),
    viewCount: 7,
    downloadCount: 3,
    items: const [],
    primaryName: 'Q3 board update.pdf',
    primaryKind: ShareItemType.file,
    itemCount: 1,
  ),
  Share(
    id: 's3',
    token: 'c',
    url: 'https://example.com/s/c',
    permission: SharePermission.download,
    createdAt: DateTime(2026, 8, 2),
    expiresAt: DateTime(2026, 8, 9),
    viewCount: 7,
    downloadCount: 3,
    items: const [],
    primaryName: 'Project handover',
    primaryKind: ShareItemType.folder,
    itemCount: 4,
  ),
  Share(
    id: 's4',
    token: 'd',
    url: 'https://example.com/s/d',
    permission: SharePermission.preview,
    createdAt: DateTime(2026, 7, 2),
    revokedAt: DateTime(2026, 7, 20),
    viewCount: 2,
    downloadCount: 0,
    items: const [],
    primaryName: 'Lease agreement.docx',
    primaryKind: ShareItemType.file,
    itemCount: 1,
  ),
];

class _Shares extends ChangeNotifier implements ShareController {
  @override
  List<Share> get shares => _shares;
  @override
  bool get loading => false;
  @override
  String? get error => null;
  @override
  Future<void> refresh({bool silent = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Repo implements DriveRepository {
  static const _empty = bool.fromEnvironment('BROWSE_EMPTY_SPACES');
  @override
  Future<List<DriveFile>> listArchiveFiles() async =>
      _empty ? const [] : _files.skip(2).take(3).toList();
  @override
  Future<List<DriveFile>> listLockedFiles() async =>
      _empty ? const [] : _files.take(2).toList();
  @override
  Future<List<DriveFile>> listTrashFiles() async =>
      _empty ? const [] : _files.skip(3).toList();
  @override
  Future<List<DriveFolder>> listTrashFolders() async =>
      _empty ? const [] : [_folders[2]];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Backup extends ChangeNotifier implements GalleryBackupController {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Uploads extends ChangeNotifier implements UploadController {
  @override
  bool get sheetVisible => false;
  @override
  List<UploadItem> get items => const [];
  @override
  UploadItemIdsSnapshot get itemIdsSnapshot =>
      const UploadItemIdsSnapshot([], 0);
  @override
  UploadSummary get summary => const UploadSummary(
    sheetVisible: false,
    itemCount: 0,
    uploadedCount: 0,
    failedCount: 0,
    activeCount: 0,
    waitingForWifi: false,
    uploading: false,
    stillGeneratingThumbs: false,
    progressPermille: 0,
    totalBytes: 0,
    completedBytes: 0,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(middle: Text(label)),
    child: Center(child: Text('$label is outside this fixture')),
  );
}

final _router = GoRouter(
  initialLocation: '/drive',
  observers: [SearchKeyboardObserver()],
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/drive', builder: (_, _) => const DriveScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/photos', builder: (_, _) => const PhotosScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/starred', builder: (_, _) => const StarredScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/shared', builder: (_, _) => const MySharesScreen()),
          ],
        ),
      ],
    ),
    for (final entry in <String, Widget>{
      'archive': const ArchiveScreen(),
      'locked': const LockedScreen(),
      'trash': const TrashScreen(),
    }.entries)
      GoRoute(
        path: '/settings/${entry.key}',
        pageBuilder: (context, state) => recoveryPage(
          context: context,
          key: state.pageKey,
          child: entry.value,
        ),
      ),
    GoRoute(
      path: '/folder/:id',
      builder: (_, state) =>
          FolderScreen(folderId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/account', builder: (_, _) => const _Placeholder('Account')),
    GoRoute(
      path: '/shared/:id',
      builder: (_, _) => const _Placeholder('Share details'),
    ),
    GoRoute(path: '/file/:id', builder: (_, _) => const _Placeholder('File')),
  ],
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  dotenv.testLoad(fileInput: '');
  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => _Auth()),
        driveControllerProvider.overrideWith((_) => _Drive()),
        driveSearchProvider.overrideWith((_) => _Search()),
        shareControllerProvider.overrideWith((_) => _Shares()),
        driveRepositoryProvider.overrideWithValue(_Repo()),
        galleryBackupControllerProvider.overrideWith((_) => _Backup()),
        uploadControllerProvider.overrideWith((_) => _Uploads()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppBrand.scheme(Brightness.light)),
        darkTheme: buildTheme(AppBrand.scheme(Brightness.dark)),
        routerConfig: _router,
        builder: (context, child) => IosAccessibility(child: child!),
      ),
    ),
  );
}
