import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/sheet/sheet_action_tile.dart';
import '../../../widgets/sheet/sheet_header.dart';

import '../../upload/upload_controller.dart';
import '../drive_controller.dart';
import 'drive_dialogs.dart';

/// Floating action button shown on the home and folder screens.  Opens a
/// modal bottom sheet with Upload File / Take Photo / Create Folder options.
class DriveFab extends ConsumerWidget {
  const DriveFab({this.parentId, super.key});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: null,
      onPressed: () => _open(context, ref),
      child: const Icon(Icons.add),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const _AddToDriveSheet(),
    );
    if (!context.mounted) return;
    if (action == 'upload') {
      await ref
          .read(uploadControllerProvider)
          .pickFiles(folderId: parentId, context: context);
    } else if (action == 'photo') {
      await ref
          .read(uploadControllerProvider)
          .pickPhoto(folderId: parentId, context: context);
    } else if (action == 'folder') {
      final name = await promptFolderName(context);
      if (name != null && context.mounted) {
        try {
          await ref.read(driveControllerProvider).createFolder(name, parentId);
        } catch (_) {}
      }
    }
  }
}

class _AddToDriveSheet extends StatelessWidget {
  const _AddToDriveSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
