import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/sheet/sheet_action_tile.dart';
import '../../../widgets/sheet/sheet_drag_handle.dart';
import '../../../widgets/sheet/sheet_header.dart';
import '../../upload/ui/folder_creation/folder_toast_controller.dart';
import '../../upload/upload_controller.dart';
import '../drive_controller.dart';
import 'drive_dialogs.dart';

/// "+" floating-action button shown on the home and folder screens.  Opens
/// a bottom sheet with Upload File / Take Photo / Create Folder options.
class DriveFab extends ConsumerWidget {
  const DriveFab({this.parentId, super.key});
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _open(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddToDriveSheet(),
    );
    if (!context.mounted) return;
    if (action == 'upload') {
      await ref.read(uploadControllerProvider).pickFiles(folderId: parentId);
    } else if (action == 'photo') {
      await ref.read(uploadControllerProvider).pickPhoto(folderId: parentId);
    } else if (action == 'folder') {
      final name = await promptFolderName(context);
      if (name != null && context.mounted) {
        final toast = ref.read(folderToastControllerProvider);
        try {
          await runWithFolderToast(
            toast,
            () => ref
                .read(driveControllerProvider)
                .createFolder(name, parentId),
          );
        } catch (_) {
          // Toast surfaces the failure.  Drive controller already owns
          // any deeper recovery; nothing more to do here.
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
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetDragHandle(),
          SheetHeader(
            title: 'Add to Drive',
            subtitle: 'Upload, capture, or create a folder',
            leadingIcon: Icons.add_rounded,
            leadingAccent: scheme.primary,
          ),
          Divider(
            height: 1,
            color: scheme.outline.withValues(alpha: .6),
            indent: 20,
            endIndent: 20,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
