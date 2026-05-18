import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/drive_models.dart';
import '../../../models/share_models.dart';
import '../../share/components/create_share_sheet.dart';
import '../drive_controller.dart';
import '../move_destination_sheet.dart';
import 'drive_action_sheet.dart';
import 'drive_dialogs.dart';
import 'share_helpers.dart';

/// Shared single-item action bottom sheets and bulk action helpers used by
/// both the home and folder screens.  Keeps the screens free of routine
/// dialog plumbing.
class DriveItemActions {
  DriveItemActions._();

  static Future<void> openFile(
    BuildContext context,
    WidgetRef ref,
    DriveFile file,
  ) async {
    final actions = <String, IconData>{
      if (file.shared)
        'revoke_share': Icons.link_off
      else
        'share': Icons.ios_share,
      'download': Icons.download,
      'move': Icons.drive_file_move_outline,
      'star': Icons.star_border,
      'delete': Icons.delete_outline,
    };
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => DriveActionSheet(title: file.name, actions: actions),
    );
    if (!context.mounted) return;
    final controller = ref.read(driveControllerProvider);
    if (action == 'share') {
      await openShareFile(context, file.id);
    } else if (action == 'revoke_share') {
      await revokeFileShares(context, ref, file);
    } else if (action == 'move') {
      final targetId = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => MoveDestinationSheet(
          title: 'Move "${file.name}"',
          currentParentId: file.parentId,
        ),
      );
      if (targetId != null && context.mounted) {
        await controller.moveFile(
          file.id,
          targetId == rootMoveDestination ? null : targetId,
        );
      }
    } else if (action == 'delete') {
      await controller.deleteItems(fileIds: [file.id]);
    } else if (action == 'star') {
      controller.toggleStar(file.id);
    }
  }

  static Future<void> openFolder(
    BuildContext context,
    WidgetRef ref,
    DriveFolder folder, {
    bool allowRename = true,
  }) async {
    final actions = <String, IconData>{
      if (folder.shared)
        'revoke_share': Icons.link_off
      else
        'share': Icons.ios_share,
      if (allowRename) 'rename': Icons.edit_outlined,
      'move': Icons.drive_file_move_outline,
      'star': Icons.star_border,
      'delete': Icons.delete_outline,
    };
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => DriveActionSheet(title: folder.name, actions: actions),
    );
    if (!context.mounted) return;
    final controller = ref.read(driveControllerProvider);
    if (action == 'share') {
      await openShareFolder(context, folder.id);
    } else if (action == 'revoke_share') {
      await revokeFolderShares(context, ref, folder);
    } else if (action == 'move') {
      final targetId = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => MoveDestinationSheet(
          title: 'Move "${folder.name}"',
          movingFolderId: folder.id,
          currentParentId: folder.parentId,
        ),
      );
      if (targetId != null && context.mounted) {
        await controller.moveFolder(
          folder.id,
          targetId == rootMoveDestination ? null : targetId,
        );
      }
    } else if (action == 'delete') {
      await controller.deleteItems(folderIds: [folder.id]);
    } else if (action == 'star') {
      controller.toggleStar(folder.id, folder: true);
    } else if (action == 'rename' && context.mounted) {
      final name = await promptFolderName(
        context,
        title: 'Rename folder',
        initial: folder.name,
        confirmLabel: 'Save',
      );
      if (name != null && context.mounted) {
        await controller.renameFolder(folder.id, name);
      }
    }
  }
}

/// Bulk-action helpers shared between Drive and Folder screens.  Operating
/// on the in-memory selection sets and the [driveControllerProvider].
class DriveBulkActions {
  DriveBulkActions._();

  static Future<void> star(
    WidgetRef ref, {
    required Set<String> fileIds,
    required Set<String> folderIds,
  }) async {
    final controller = ref.read(driveControllerProvider);
    for (final id in fileIds) {
      controller.toggleStar(id);
    }
    for (final id in folderIds) {
      controller.toggleStar(id, folder: true);
    }
  }

  static Future<void> share(
    BuildContext context,
    WidgetRef ref, {
    required Set<String> fileIds,
    required Set<String> folderIds,
  }) async {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    final items = <ShareItemRequest>[
      for (final id in fileIds)
        ShareItemRequest(type: ShareItemType.file, id: id),
      for (final id in folderIds)
        ShareItemRequest(
          type: ShareItemType.folder,
          id: id,
          mode: FolderShareMode.snapshot,
        ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateShareSheet(items: items),
    );
  }

  static Future<void> move(
    BuildContext context,
    WidgetRef ref, {
    required Set<String> fileIds,
    required Set<String> folderIds,
    String? currentParentId,
  }) async {
    final movingFolderId = folderIds.length == 1 && fileIds.isEmpty
        ? folderIds.first
        : null;
    final targetId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MoveDestinationSheet(
        title: 'Move ${fileIds.length + folderIds.length} items',
        movingFolderId: movingFolderId,
        currentParentId: currentParentId,
      ),
    );
    if (targetId == null || !context.mounted) return;
    final dest = targetId == rootMoveDestination ? null : targetId;
    final controller = ref.read(driveControllerProvider);
    for (final id in fileIds) {
      await controller.moveFile(id, dest);
    }
    for (final id in folderIds) {
      await controller.moveFolder(id, dest);
    }
  }

  static Future<bool> delete(
    BuildContext context,
    WidgetRef ref, {
    required Set<String> fileIds,
    required Set<String> folderIds,
  }) async {
    final total = fileIds.length + folderIds.length;
    final ok = await confirmDelete(context, total);
    if (!ok || !context.mounted) return false;
    await ref.read(driveControllerProvider).deleteItems(
          fileIds: fileIds.toList(),
          folderIds: folderIds.toList(),
        );
    return true;
  }
}
