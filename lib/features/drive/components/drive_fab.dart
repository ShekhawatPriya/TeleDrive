import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../widgets/ios_menu/ios_menu_models.dart';
import '../../../widgets/ios_menu/native_menu_payload.dart';
import '../../../widgets/native_glass_button.dart';
import '../../../widgets/sheet/adaptive_sheet.dart';
import '../../../widgets/sheet/ios_action_group.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/sheet/sheet_action_tile.dart';
import '../../../widgets/sheet/sheet_header.dart';

import '../../upload/upload_controller.dart';
import '../../upload/upload_source_picker.dart';
import '../drive_controller.dart';
import 'drive_dialogs.dart';
import '../../../widgets/app_message.dart';

/// Floating add control shown on the home and folder screens. On iOS a
/// native glass button opens a UIKit menu straight from the control (Choose
/// from Photos / Choose Files / Take Photo / New Folder), as the Files app
/// does; widget tests and hosts without the bridge open the grouped sheet.
/// Android keeps its FAB and bottom sheet.
class DriveFab extends ConsumerStatefulWidget {
  const DriveFab({this.parentId, super.key});
  final String? parentId;

  @override
  ConsumerState<DriveFab> createState() => _DriveFabState();
}

class _DriveFabState extends ConsumerState<DriveFab> {
  Map<String, VoidCallback> _menuActions = {};

  String? get parentId => widget.parentId;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return Semantics(
        label: 'Add files or create a folder',
        child: NativeGlassButton(
          label: 'Add',
          symbol: 'plus',
          icon: CupertinoIcons.plus,
          size: 60,
          symbolSize: 24,
          onPressed: _open,
          menuBuilder: () {
            final payload = NativeMenuPayload([
              IosMenuSection([
                IosMenuItem(
                  label: 'Choose from Photos',
                  onTap: () => _run('photos'),
                ),
                IosMenuItem(label: 'Choose Files', onTap: () => _run('files')),
                IosMenuItem(label: 'Take Photo', onTap: () => _run('photo')),
              ]),
              IosMenuSection([
                IosMenuItem(label: 'New Folder', onTap: () => _run('folder')),
              ]),
            ]);
            _menuActions = payload.actions;
            return payload.sections;
          },
          onMenuAction: (id) => _menuActions[id]?.call(),
        ),
      );
    }
    return FloatingActionButton(
      heroTag: null,
      tooltip: 'Add files or create a folder',
      onPressed: _open,
      child: const Icon(Icons.add),
    );
  }

  Future<void> _open() async {
    ModalRoute<dynamic>? sheetRoute;
    final action = await showAdaptiveSheet<String>(
      context: context,
      builder: (ctx) {
        sheetRoute = ModalRoute.of(ctx);
        return const _AddToDriveSheet();
      },
    );
    await sheetRoute?.completed;
    if (!mounted || action == null) return;
    if (action == 'upload') {
      final source = Theme.of(context).platform == TargetPlatform.iOS
          ? await chooseUploadSource(context)
          : 'files';
      if (!mounted || source == null) return;
      await _run(source == 'photos' ? 'photos' : 'files');
      return;
    }
    await _run(action);
  }

  Future<void> _run(String action) async {
    if (!mounted) return;
    UploadController upload() => ref.read(uploadControllerProvider);
    switch (action) {
      case 'photos':
        await upload().pickPhotos(folderId: parentId, context: context);
      case 'files':
        await upload().pickFiles(folderId: parentId, context: context);
      case 'photo':
        await upload().pickPhoto(folderId: parentId, context: context);
      case 'folder':
        final name = await promptFolderName(context);
        if (name == null || !mounted) return;
        try {
          await ref.read(driveControllerProvider).createFolder(name, parentId);
        } catch (_) {
          if (mounted) {
            showAppMessage(
              context,
              'Could not create folder. Please try again.',
              error: true,
            );
          }
        }
    }
  }
}

class _AddToDriveSheet extends StatelessWidget {
  const _AddToDriveSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(title: 'Add to Drive'),
            IosActionGroup(
              children: [
                IosActionRow(
                  label: 'Upload',
                  icon: CupertinoIcons.arrow_up_doc,
                  onPressed: () => Navigator.pop(context, 'upload'),
                ),
                IosActionRow(
                  label: 'Take Photo',
                  icon: CupertinoIcons.camera,
                  onPressed: () => Navigator.pop(context, 'photo'),
                ),
                IosActionRow(
                  label: 'Create Folder',
                  icon: CupertinoIcons.folder_badge_plus,
                  onPressed: () => Navigator.pop(context, 'folder'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: 'Add to Drive',
            subtitle: 'Upload, capture, or create a folder',
            leadingIcon: Icons.add_rounded,
            leadingAccent: scheme.primary,
          ),
          SheetActionTile(
            label: 'Upload Photos',
            subtitle: 'Choose photos and videos',
            icon: Icons.photo_library_outlined,
            onTap: () => Navigator.pop(context, 'photos'),
          ),
          SheetActionTile(
            label: 'Upload File',
            subtitle: 'Pick from your device',
            icon: Icons.upload_file_outlined,
            onTap: () => Navigator.pop(context, 'upload'),
          ),
          SheetActionTile(
            label: 'Take Photo',
            subtitle: 'Capture with camera',
            icon: Icons.camera_alt_outlined,
            onTap: () => Navigator.pop(context, 'photo'),
          ),
          SheetActionTile(
            label: 'Create Folder',
            subtitle: 'Organize your files',
            icon: Icons.create_new_folder_outlined,
            onTap: () => Navigator.pop(context, 'folder'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
