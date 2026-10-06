// Simulator-only recovery navigation fixture. Production uses lib/main.dart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/core/navigation/recovery_page.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_header_widgets.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/profile/archive_screen.dart';
import 'package:flutter_m_fsdk/features/profile/locked_screen.dart';
import 'package:flutter_m_fsdk/features/profile/trash_screen.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/widgets/native_tab_bar.dart';
import 'ios_design_preview.dart' show PreviewAuth;

const _file = DriveFile(
  id: 'fixture',
  name: 'Recovery document.pdf',
  kind: FileKind.pdf,
  size: 42000,
  createdAt: '2026-10-01',
  modifiedAt: '2026-10-01',
  parentId: null,
  starred: false,
);
final _repo = _Repository();

class _Repository implements DriveRepository {
  bool populated = false;
  Future<List<DriveFile>> _files() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return populated ? [_file] : [];
  }

  @override
  Future<List<DriveFile>> listArchiveFiles() => _files();
  @override
  Future<List<DriveFile>> listLockedFiles() => _files();
  @override
  Future<List<DriveFile>> listTrashFiles() => _files();
  @override
  Future<List<DriveFolder>> listTrashFolders() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState get state => const DriveState();
  @override
  DriveFile? file(String id) => _file;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const _Home()),
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
  ],
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  dotenv.testLoad(fileInput: '');
  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => PreviewAuth()),
        driveControllerProvider.overrideWith((_) => _Drive()),
        driveRepositoryProvider.overrideWithValue(_repo),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppBrand.scheme(Brightness.light)),
        routerConfig: _router,
      ),
    ),
  );
  if (const bool.fromEnvironment('RECOVERY_RECORDING')) {
    unawaited(_recording());
  }
}

Future<void> _recording() async {
  await Future<void>.delayed(const Duration(seconds: 3));
  for (final populated in [false, true]) {
    _repo.populated = populated;
    for (final page in ['archive', 'locked', 'trash']) {
      unawaited(_router.push('/settings/$page'));
      await Future<void>.delayed(const Duration(seconds: 2));
      _router.pop();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}

class _Home extends StatefulWidget {
  const _Home();
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recovery navigation fixture')),
    body: Column(
      children: [
        SwitchListTile.adaptive(
          title: const Text('Populated fixture'),
          value: _repo.populated,
          onChanged: (value) => setState(() => _repo.populated = value),
        ),
        DriveQuickActions(
          onArchiveTap: () => context.push('/settings/archive'),
          onLockedTap: () => context.push('/settings/locked'),
          onTrashTap: () => context.push('/settings/trash'),
        ),
      ],
    ),
    bottomNavigationBar: SizedBox(
      height: 88,
      child: NativeTabBar(selectedIndex: 0, onSelected: (_) {}),
    ),
  );
}
