// Local-only visual QA entry point. Never used by lib/main.dart or release builds.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/core/network/backend_resolver.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/profile/storage_summary_controller.dart';
import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_m_fsdk/features/profile/cache_controller.dart';
import 'package:flutter_m_fsdk/features/profile/settings_screen.dart';
import 'package:flutter_m_fsdk/features/profile/theme_controller.dart';
import 'package:flutter_m_fsdk/features/profile/profile_screen.dart';
import 'package:flutter_m_fsdk/features/profile/my_data_screen.dart';
import 'package:flutter_m_fsdk/features/profile/free_up_space_screen.dart';
import 'package:flutter_m_fsdk/features/profile/free_up_space/free_up_space_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/widgets/account_button.dart';
import 'package:flutter_m_fsdk/widgets/floating_pill_navigation_bar.dart';
import 'package:flutter_m_fsdk/widgets/ios_more_menu.dart';
import 'package:flutter_m_fsdk/widgets/sheet/adaptive_sheet.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_action_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  dotenv.testLoad(fileInput: '');
  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => PreviewAuth()),
        storageSummaryControllerProvider.overrideWith((_) => PreviewStorage()),
        appSettingsControllerProvider.overrideWith((_) => PreviewSettings()),
        backendResolverProvider.overrideWith((_) => PreviewBackend()),
        cacheControllerProvider.overrideWith((_) => PreviewCache()),
        freeUpSpaceControllerProvider.overrideWith((_) => PreviewFreeSpace()),
        driveControllerProvider.overrideWith((_) => PreviewDrive()),
      ],
      child: const PreviewApp(),
    ),
  );
}

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const PreviewHome()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    GoRoute(path: '/profile/my-data', builder: (_, _) => const MyDataScreen()),
    GoRoute(
      path: '/profile/free-up-space',
      builder: (_, _) => const FreeUpSpaceScreen(),
    ),
  ],
);

class PreviewApp extends ConsumerWidget {
  const PreviewApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    routerConfig: router,
    theme: buildTheme(AppBrand.scheme(Brightness.light)),
    darkTheme: buildTheme(AppBrand.scheme(Brightness.dark)),
    themeMode: ref.watch(themeControllerProvider).mode,
  );
}

class PreviewHome extends StatefulWidget {
  const PreviewHome({super.key});
  @override
  State<PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<PreviewHome> {
  int tab = 0;
  String layout = 'List', sort = 'Name';
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ['Drive', 'Photos', 'Starred', 'Shared'][tab],
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              IosMoreButton(
                sectionsBuilder: (_) => [
                  IosMenuSection([
                    for (final label in [
                      'Select',
                      'New Folder',
                      'Scan Documents',
                    ])
                      IosMenuItem(
                        label: label,
                        onTap: () => _previewActions(context),
                      ),
                  ]),
                  IosMenuSection([
                    for (final label in ['Icons', 'List'])
                      IosMenuItem(
                        label: label,
                        checked: layout == label,
                        onTap: () => setState(() => layout = label),
                      ),
                  ]),
                  IosMenuSection([
                    for (final label in ['Name', 'Kind', 'Size', 'Date'])
                      IosMenuItem(
                        label: label,
                        checked: sort == label,
                        subtitle: sort == label ? 'Ascending' : null,
                        onTap: () => setState(() => sort = label),
                      ),
                  ]),
                ],
              ),
              const SizedBox(width: 8),
              const AccountButton(),
            ],
          ),
          const SizedBox(height: 20),
          const CupertinoSearchTextField(
            placeholder: 'Search files and folders',
          ),
          const SizedBox(height: 24),
          Text('Library', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (var i = 0; i < 12; i++)
            Container(
              height: 104,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.folder_fill,
                    color: [Colors.blue, Colors.indigo, Colors.orange][i % 3],
                    size: 40,
                  ),
                  const SizedBox(width: 20),
                  Text(['Documents', 'Summer photos', 'Projects'][i % 3]),
                ],
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: FloatingPillNavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (index) => setState(() => tab = index),
    ),
  );
}

class PreviewAuth extends ChangeNotifier implements AuthController {
  @override
  AuthUser get user => const AuthUser(
    userId: 1,
    telegramId: 123456789,
    firstName: 'Alex',
    lastName: 'Morgan',
    username: 'alexmorgan',
  );
  @override
  AccountVault get vault => const AccountVault.empty();
  @override
  bool get telegramConnected => true;
  @override
  int get largeUploadThresholdBytes => 100 * 1024 * 1024;
  @override
  Future<void> refreshProfile() async {}
  @override
  Future<void> refreshSavedAccountSnapshots() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class PreviewStorage extends ChangeNotifier
    implements StorageSummaryController {
  @override
  StorageSummary? get value => StorageSummary.fromJson({
    'totalFiles': 42,
    'totalBytes': 471859200,
    'imageBytes': 104857600,
    'imageCount': 36,
    'videoBytes': 367001600,
    'videoCount': 6,
  });
  @override
  Future<void> ensureLoaded({bool force = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class PreviewSettings extends ChangeNotifier implements AppSettingsController {
  @override
  AppSettingsState get state => const AppSettingsState(loaded: true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class PreviewBackend extends ChangeNotifier implements BackendResolver {
  @override
  BackendStatus get status => BackendStatus.connected;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class PreviewCache extends CacheController {
  @override
  Future<void> refreshCacheStats() async {}
}

class PreviewFreeSpace extends ChangeNotifier implements FreeUpSpaceController {
  @override
  FreeUpSpaceState get state => const FreeUpSpaceState(
    eligibleBytes: 104857600,
    eligibleCount: 12,
    photoCount: 12,
    photoBytes: 104857600,
  );
  @override
  Future<void> scan() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class PreviewDrive extends ChangeNotifier implements DriveController {
  @override
  List<Never> get folders => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void _previewActions(BuildContext context) {
  showAdaptiveSheet<String>(
    context: context,
    builder: (_) => const DriveActionSheet(
      title: '20250613_051209.heic',
      subtitle: 'HEIC · 452 KB · Today',
      leadingIcon: CupertinoIcons.photo,
      actions: [
        SheetActionItem(id: 'share', label: 'Share', icon: Icons.share),
        SheetActionItem(
          id: 'download',
          label: 'Download',
          icon: Icons.download,
        ),
        SheetActionItem(id: 'star', label: 'Star', icon: Icons.star),
        SheetActionItem(id: 'move', label: 'Move', icon: Icons.folder),
        SheetActionItem(id: 'lock', label: 'Lock', icon: Icons.lock),
        SheetActionItem(id: 'archive', label: 'Archive', icon: Icons.archive),
        SheetActionItem(
          id: 'delete',
          label: 'Delete',
          icon: Icons.delete,
          destructive: true,
        ),
      ],
    ),
  );
}
