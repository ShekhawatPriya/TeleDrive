// Simulator-only native interaction fixture; production uses lib/main.dart.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_item_context_menu.dart';
import 'package:flutter_m_fsdk/features/drive/components/drive_selection_bar.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_m_fsdk/widgets/ios_more_menu.dart';
import 'package:flutter_m_fsdk/widgets/media_thumb.dart';
import 'ios_design_preview.dart' show PreviewAuth;

const previewFile = DriveFile(
  id: 'photo',
  name: 'Alpine afternoon.jpg',
  kind: FileKind.image,
  size: 2400000,
  modifiedAt: '2026-09-17',
  createdAt: '2026-09-17',
  parentId: null,
  starred: false,
  thumbnailUrl: String.fromEnvironment('PHOTO_PREVIEW_PATH'),
);
void main() => runApp(
  ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((_) => PreviewAuth()),
      driveControllerProvider.overrideWith((_) => _Drive()),
    ],
    child: const _Preview(),
  ),
);

class _Drive extends ChangeNotifier implements DriveController {
  DriveFile current = previewFile;
  @override
  DriveFile? file(String id) => current;
  @override
  Future<void> toggleStar(String id, {bool folder = false}) async {
    current = current.copyWith(starred: !current.starred);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  bool select = false, dark = true;
  int count = 0;
  String message = 'Touch and hold a photo';
  String layout = 'List';
  Widget selection(bool actions) => DriveSelectionBar(
    selectedCount: count,
    actionsOnly: actions,
    onCancel: () => setState(() => select = false),
    onShare: () => setState(() => message = 'Share selected'),
    onStar: () => setState(() => message = 'Star selected'),
    onMove: () => setState(() => message = 'Move selected'),
    onDelete: () => setState(() => message = 'Delete selected'),
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(
      AppBrand.scheme(dark ? Brightness.dark : Brightness.light),
    ),
    home: Scaffold(
      appBar: select
          ? null
          : AppBar(
              title: const Text('Your drive'),
              actions: [
                CupertinoButton(
                  onPressed: () => setState(() => dark = !dark),
                  child: const Icon(CupertinoIcons.sun_max),
                ),
                IosMoreButton(
                  sectionsBuilder: (_) => [
                    IosMenuSection([
                      IosMenuItem(
                        label: 'Select',
                        onTap: () => setState(() {
                          select = true;
                          count = 0;
                        }),
                      ),
                    ]),
                    IosMenuSection([
                      for (final value in ['Icons', 'List'])
                        IosMenuItem(
                          label: value,
                          checked: value == layout,
                          onTap: () => setState(() => layout = value),
                        ),
                    ]),
                    IosMenuSection([
                      for (final value in ['Name', 'Kind', 'Size', 'Date'])
                        IosMenuItem(
                          label: value,
                          checked: value == 'Name',
                          onTap: () {},
                        ),
                    ]),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          if (select) selection(false),
          Padding(padding: const EdgeInsets.all(20), child: Text(message)),
          Expanded(
            child: ListView.builder(
              itemCount: 16,
              padding: const EdgeInsets.all(20),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DriveItemContextMenu(
                  file: previewFile,
                  enabled: !select,
                  onOpen: () => setState(() => message = 'Opened photo $index'),
                  onSelect: () => setState(() {
                    select = true;
                    count = 1;
                  }),
                  child: SizedBox(
                    height: 180,
                    child: GestureDetector(
                      onTap: () => setState(() => count++),
                      child: Semantics(
                        label: 'Photo $index',
                        child: MediaThumb(
                          file: previewFile,
                          fit: BoxFit.cover,
                          radius: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (select) selection(true),
        ],
      ),
    ),
  );
}
