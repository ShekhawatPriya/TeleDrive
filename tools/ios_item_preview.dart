// Simulator-only native interaction fixture; production uses lib/main.dart.
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_m_fsdk/core/media/item_preview_loader.dart';
import 'package:flutter_m_fsdk/core/media/thumbnail_loader.dart';
import 'package:flutter_m_fsdk/widgets/account_button.dart';
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
import 'package:flutter_m_fsdk/widgets/file_list_tile.dart';
import 'package:flutter_m_fsdk/widgets/teledrive_app_bar.dart';
import 'package:flutter_m_fsdk/features/search/search_controller.dart';
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
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  dotenv.testLoad(fileInput: '');
  runApp(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => PreviewAuth()),
        driveControllerProvider.overrideWith((_) => _Drive()),
        itemPreviewLoaderProvider.overrideWith(
          (ref) => ItemPreviewLoader(
            thumbnails: ref.watch(thumbnailLoaderProvider),
            scheduler: ref.watch(thumbnailSchedulerProvider),
            document: (_, _) async =>
                File(const String.fromEnvironment('PDF_PREVIEW_PATH')),
          ),
        ),
      ],
      child: const _Preview(),
    ),
  );
}

const pdfFile = DriveFile(
  id: 'pdf',
  name: 'Project overview.pdf',
  kind: FileKind.pdf,
  size: 1024,
  modifiedAt: '2026-09-17',
  createdAt: '',
  parentId: null,
  starred: false,
);
const unknownFile = DriveFile(
  id: 'unknown',
  name: 'Archive.vaultbackup',
  kind: FileKind.other,
  size: 4000,
  modifiedAt: '2026-09-17',
  createdAt: '',
  parentId: null,
  starred: false,
);

class _Drive extends ChangeNotifier implements DriveController {
  DriveFile current = previewFile;
  @override
  DriveFile? file(String id) => id == 'photo'
      ? current
      : id == 'pdf'
      ? pdfFile
      : unknownFile;
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
  DriveFile sample = previewFile;
  String message = 'Touch and hold a photo';
  String layout = 'List';
  Widget selection(bool actions) => DriveSelectionBar(
    selectedCount: count,
    actionsOnly: actions,
    onCancel: () => setState(() => select = false),
    onSelectAll: () => setState(() => count = 16),
    onClear: () => setState(() => count = 0),
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
                  size: 44,
                  visualSize: 34,
                  sectionsBuilder: (_) => [
                    IosMenuSection([
                      IosMenuItem(
                        label: 'PDF fixture',
                        onTap: () => setState(() => sample = pdfFile),
                      ),
                      IosMenuItem(
                        label: 'Unsupported fixture',
                        onTap: () => setState(() => sample = unknownFile),
                      ),
                    ]),
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
                const AccountButton(avatarSize: 44),
              ],
            ),
      body: Column(
        children: [
          if (select) selection(false),
          if (select)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: DriveSearchField(
                scope: SearchScope.drive,
                selectionMode: true,
              ),
            ),
          if (select)
            const SizedBox(height: 20)
          else
            Padding(padding: const EdgeInsets.all(20), child: Text(message)),
          Expanded(
            child: ListView.builder(
              itemCount: 16,
              padding: select ? EdgeInsets.zero : const EdgeInsets.all(20),
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(bottom: select ? 0 : 16),
                child: DriveItemContextMenu(
                  file: sample,
                  enabled: !select,
                  onOpen: () => setState(() => message = 'Opened photo $index'),
                  onSelect: () => setState(() {
                    select = true;
                    count = 1;
                  }),
                  child: select
                      ? Semantics(
                          label: 'Photo $index',
                          image: true,
                          child: FileListTile(
                            name: index == 0
                                ? sample.name
                                : 'Alpine afternoon $index.jpg',
                            subtitle: 'JPG · 2.3 MB',
                            file: sample,
                            selected: index < count,
                            onTap: () => setState(() => count++),
                          ),
                        )
                      : SizedBox(
                          height: 180,
                          child: GestureDetector(
                            onTap: () => setState(() => count++),
                            child: Semantics(
                              label: 'Photo $index',
                              child: MediaThumb(
                                file: sample,
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
