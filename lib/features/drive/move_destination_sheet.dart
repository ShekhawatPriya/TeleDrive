import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/drive_models.dart';
import 'drive_controller.dart';

const rootMoveDestination = '__teledrive_root__';

class MoveDestinationSheet extends ConsumerWidget {
  const MoveDestinationSheet({
    required this.title,
    this.movingFolderId,
    this.currentParentId,
    super.key,
  });

  final String title;
  final String? movingFolderId;
  final String? currentParentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveControllerProvider);
    final excluded = _excludedIds(drive.folders);
    final roots = drive.folders.where((f) => f.parentId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .35,
        maxChildSize: .9,
        builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  ListTile(
                    leading: const Icon(Icons.drive_folder_upload_outlined),
                    title: const Text('My Drive'),
                    enabled: currentParentId != null,
                    onTap: currentParentId == null
                        ? null
                        : () => Navigator.pop(context, rootMoveDestination),
                  ),
                  const Divider(height: 1),
                  for (final folder in roots)
                    ..._folderRows(context, drive.folders, folder, excluded, 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<String> _excludedIds(List<DriveFolder> folders) {
    final moving = movingFolderId;
    if (moving == null) return const {};
    final excluded = <String>{moving};
    void visit(String id) {
      for (final child in folders.where((f) => f.parentId == id)) {
        if (excluded.add(child.id)) visit(child.id);
      }
    }

    visit(moving);
    return excluded;
  }

  List<Widget> _folderRows(
    BuildContext context,
    List<DriveFolder> folders,
    DriveFolder folder,
    Set<String> excluded,
    int depth,
  ) {
    if (excluded.contains(folder.id)) return const [];
    final children = folders.where((f) => f.parentId == folder.id).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return [
      ListTile(
        leading: Padding(
          padding: EdgeInsets.only(left: depth * 18),
          child: const Icon(Icons.folder_outlined),
        ),
        title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        enabled: currentParentId != folder.id,
        onTap: currentParentId == folder.id
            ? null
            : () => Navigator.pop(context, folder.id),
      ),
      for (final child in children)
        ..._folderRows(context, folders, child, excluded, depth + 1),
    ];
  }
}
