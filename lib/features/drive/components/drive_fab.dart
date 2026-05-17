import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        await ref.read(driveControllerProvider).createFolder(name, parentId);
      }
    }
  }
}

class _AddToDriveSheet extends StatelessWidget {
  const _AddToDriveSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Add to Drive',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Upload File'),
              onTap: () => Navigator.pop(context, 'upload'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Create Folder'),
              onTap: () => Navigator.pop(context, 'folder'),
            ),
          ],
        ),
      ),
    );
  }
}
