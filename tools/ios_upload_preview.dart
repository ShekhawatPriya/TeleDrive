// Isolated native-tab visual fixture. Never install this entry point on a user's
// physical device or import it from lib/main.dart.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_controller.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_m_fsdk/features/upload/ui/components/bottom_action_system.dart';
import 'package:flutter_m_fsdk/features/upload/ui/upload_panel_host.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/widgets/floating_pill_navigation_bar.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        uploadControllerProvider.overrideWith((_) => _Uploads()),
        driveControllerProvider.overrideWith((_) => _Drive()),
      ],
      child: const _Preview(),
    ),
  );
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  bool dark = true;
  int tab = 0;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(
      AppBrand.scheme(dark ? Brightness.dark : Brightness.light),
    ),
    home: Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Transfer preview'),
        actions: [
          CupertinoButton(
            onPressed: () => setState(() => dark = !dark),
            child: const Icon(CupertinoIcons.sun_max),
          ),
        ],
      ),
      body: UploadPanelHost(
        child: Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: 18,
              itemBuilder: (_, i) => Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 12),
                color: [Colors.blueGrey, Colors.brown, Colors.indigo][i % 3],
                child: Center(child: Text('Library item ${i + 1}')),
              ),
            ),
            const Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: BottomActionSystem(showFab: false),
            ),
            const _OpenOnLaunch(),
          ],
        ),
      ),
      bottomNavigationBar: FloatingPillNavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
      ),
    ),
  );
}

class _OpenOnLaunch extends StatefulWidget {
  const _OpenOnLaunch();
  @override
  State<_OpenOnLaunch> createState() => _OpenOnLaunchState();
}

class _OpenOnLaunchState extends State<_OpenOnLaunch> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showUploadPanel(context);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Drive extends ChangeNotifier implements DriveController {
  @override
  DriveState get state => const DriveState();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Uploads extends ChangeNotifier implements UploadController {
  @override
  List<UploadItem> get items => [
    UploadItem(
      localId: 'one',
      uploadClientId: 'one',
      name: 'Weekend photo.jpg',
      size: 2400000,
      mimeType: 'image/jpeg',
      path: '',
      status: UploadStatus.waitingForWifi,
    ),
  ];
  @override
  bool get sheetVisible => true;
  @override
  UploadItemIdsSnapshot get itemIdsSnapshot =>
      const UploadItemIdsSnapshot(['one'], 0);
  @override
  UploadSummary get summary => const UploadSummary(
    sheetVisible: true,
    itemCount: 1,
    uploadedCount: 0,
    failedCount: 0,
    activeCount: 1,
    waitingForWifi: true,
    uploading: true,
    stillGeneratingThumbs: false,
    progressPermille: 0,
    totalBytes: 2400000,
    completedBytes: 0,
  );
  @override
  Future<void> enableMobileDataUploads() async {}
  @override
  Future<void> cancelItem(String localId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
