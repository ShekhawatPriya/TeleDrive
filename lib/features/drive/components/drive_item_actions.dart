import 'package:flutter/material.dart';
import '../../../widgets/sheet/adaptive_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'drive_bulk_actions.dart';
import 'drive_bulk_actions.dart';

import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../profile/app_settings_controller.dart';
import '../drive_controller.dart';
import '../folder_delete_guard.dart';
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
    final actions = <SheetActionItem>[
      _shareAction(file.shared),
      const SheetActionItem(
        id: 'download',
        label: 'Download',
        icon: Icons.download,
      ),
      const SheetActionItem(
        id: 'move',
        label: 'Move',
        icon: Icons.drive_file_move_outline,
      ),
      _lockAction,
      _archiveAction,
      _starAction(file.starred),
      _deleteAction,
    ];
    final action = await _showActions(
      context,
      title: file.name,
      subtitle: _fileSubtitle(file),
      file: file,
      actions: actions,
    );
    if (!context.mounted) return;
    final controller = ref.read(driveControllerProvider);
    if (action == 'share') {
      await openShareFile(context, file.id);
    } else if (action == 'revoke_share') {
      await revokeFileShares(context, ref, file);
    } else if (action == 'move') {
      final targetId = await _pickMoveDestination(
        context,
        title: 'Move "${file.name}"',
        currentParentId: file.parentId,
      );
      if (targetId != null && context.mounted) {
        await controller.moveFile(
          file.id,
          targetId == rootMoveDestination ? null : targetId,
        );
      }
    } else if (action == 'delete') {
      final trashEnabled = ref
          .read(appSettingsControllerProvider)
          .state
          .trashEnabled;
      final ok = await confirmDelete(context, 1, trashEnabled: trashEnabled);
      if (ok && context.mounted) {
        await controller.deleteItems(fileIds: [file.id]);
      }
    } else if (action == 'star') {
      await controller.toggleStar(file.id);
    } else if (action == 'lock') {
      try {
        await controller.lockFile(file.id);
        if (context.mounted) {
          _showShelfSnackBar(context, 'Moved to Locked');
        }
      } catch (_) {
        if (context.mounted) {
          _showShelfSnackBar(context, 'Could not lock file.');
        }
      }
    } else if (action == 'archive') {
      try {
        await controller.archiveFile(file.id);
        if (context.mounted) {
          _showShelfSnackBar(context, 'Moved to Archive');
        }
      } catch (_) {
        if (context.mounted) {
          _showShelfSnackBar(context, 'Could not archive file.');
        }
      }
    }
  }

  static Future<void> openFolder(
    BuildContext context,
    WidgetRef ref,
    DriveFolder folder, {
    bool allowRename = true,
  }) async {
    final actions = <SheetActionItem>[
      _shareAction(folder.shared),
      if (allowRename)
        const SheetActionItem(
          id: 'rename',
          label: 'Rename',
          icon: Icons.edit_outlined,
        ),
      const SheetActionItem(
        id: 'move',
        label: 'Move',
        icon: Icons.drive_file_move_outline,
      ),
      _starAction(folder.starred),
      _deleteAction,
    ];
    final action = await _showActions(
      context,
      title: folder.name,
      subtitle: _folderSubtitle(folder),
      folder: folder,
      actions: actions,
    );
    if (!context.mounted) return;
    final controller = ref.read(driveControllerProvider);
    if (action == 'share') {
      await openShareFolder(context, folder.id);
    } else if (action == 'revoke_share') {
      await revokeFolderShares(context, ref, folder);
    } else if (action == 'move') {
      final targetId = await _pickMoveDestination(
        context,
        title: 'Move "${folder.name}"',
        movingFolderId: folder.id,
        currentParentId: folder.parentId,
      );
      if (targetId != null && context.mounted) {
        await controller.moveFolder(
          folder.id,
          targetId == rootMoveDestination ? null : targetId,
        );
      }
    } else if (action == 'delete') {
      final trashEnabled = ref
          .read(appSettingsControllerProvider)
          .state
          .trashEnabled;
      final validation = FolderDeleteGuard.validateFolder(
        controller.state,
        folder,
      );
      if (!validation.canDelete) {
        showFolderNotEmptyToast(context);
        return;
      }
      final ok = await confirmDelete(context, 1, trashEnabled: trashEnabled);
      if (ok && context.mounted) {
        await controller.deleteItems(folderIds: [folder.id]);
      }
    } else if (action == 'star') {
      await controller.toggleStar(folder.id, folder: true);
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

const _deleteAction = SheetActionItem(
  id: 'delete',
  label: 'Delete',
  icon: Icons.delete_outline,
  destructive: true,
);

const _lockAction = SheetActionItem(
  id: 'lock',
  label: 'Lock',
  icon: Icons.lock_outline,
);

const _archiveAction = SheetActionItem(
  id: 'archive',
  label: 'Archive',
  icon: Icons.archive_outlined,
);

SheetActionItem _shareAction(bool shared) {
  return shared
      ? const SheetActionItem(
          id: 'revoke_share',
          label: 'Revoke share',
          icon: Icons.link_off,
        )
      : const SheetActionItem(
          id: 'share',
          label: 'Share',
          icon: Icons.ios_share,
        );
}

SheetActionItem _starAction(bool starred) {
  return SheetActionItem(
    id: 'star',
    label: starred ? 'Unstar' : 'Star',
    icon: starred ? Icons.star : Icons.star_border,
  );
}

Future<String?> _showActions(
  BuildContext context, {
  required String title,
  required String subtitle,
  DriveFile? file,
  DriveFolder? folder,
  required List<SheetActionItem> actions,
}) {
  return showAdaptiveSheet<String>(
    context: context,
    builder: (_) => DriveActionSheet(
      title: title,
      subtitle: subtitle,
      file: file,
      folder: folder,
      actions: actions,
    ),
  );
}

Future<String?> _pickMoveDestination(
  BuildContext context, {
  required String title,
  String? movingFolderId,
  String? currentParentId,
}) {
  return showAdaptiveSheet<String>(
    context: context,
    scrollBody: false,
    builder: (_) => MoveDestinationSheet(
      title: title,
      movingFolderId: movingFolderId,
      currentParentId: currentParentId,
    ),
  );
}

String _fileSubtitle(DriveFile file) {
  final parts = <String>[
    formatLabel(file),
    formatFileSize(file.size),
    if (formatDate(file.modifiedAt).isNotEmpty) formatDate(file.modifiedAt),
  ];
  return parts.join(' • ');
}

String _folderSubtitle(DriveFolder folder) {
  final parts = <String>['Folder'];
  if (folder.recursiveFileCount > 0) {
    parts.add(
      '${folder.recursiveFileCount} '
      '${folder.recursiveFileCount == 1 ? 'item' : 'items'}',
    );
  }
  if (folder.recursiveSize > 0) {
    parts.add(formatFileSize(folder.recursiveSize));
  }
  return parts.join(' • ');
}

void _showShelfSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}
