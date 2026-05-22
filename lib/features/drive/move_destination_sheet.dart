import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/drive_models.dart';
import '../../widgets/sheet/sheet_header.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final excluded = _excludedIds(drive.folders);
    final roots = drive.folders.where((f) => f.parentId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .35,
        maxChildSize: .9,
        builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              title: title,
              leadingIcon: Icons.drive_file_move_outlined,
              leadingAccent: scheme.primary,
              trailing: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('My Drive'),
                    enabled: currentParentId != null,
                    onTap: currentParentId == null
                        ? null
                        : () => Navigator.pop(context, rootMoveDestination),
                  ),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                  ),
                  for (final folder in roots)
                    ..._folderRows(
                      context,
                      scheme,
                      drive.folders,
                      folder,
                      excluded,
                      0,
                    ),
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
    ColorScheme scheme,
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
        contentPadding: EdgeInsetsDirectional.only(
          start: AppSpacing.md + depth * 20,
          end: AppSpacing.md,
        ),
        leading: Icon(Icons.folder_outlined, color: scheme.onSurfaceVariant),
        title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        enabled: currentParentId != folder.id,
        onTap: currentParentId == folder.id
            ? null
            : () => Navigator.pop(context, folder.id),
      ),
      for (final child in children)
        ..._folderRows(context, scheme, folders, child, excluded, depth + 1),
    ];
  }
}
