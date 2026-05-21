import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'drive_bulk_actions.dart';
import 'drive_bulk_actions.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
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
      if (file.shared)
        const SheetActionItem(
          id: 'revoke_share',
          label: 'Revoke share',
          icon: Icons.link_off,
        )
      else
        const SheetActionItem(
          id: 'share',
          label: 'Share',
          icon: Icons.ios_share,
        ),
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
      SheetActionItem(
        id: 'star',
        label: file.starred ? 'Unstar' : 'Star',
        icon: file.starred ? Icons.star : Icons.star_border,
      ),
      const SheetActionItem(
        id: 'delete',
        label: 'Delete',
        icon: Icons.delete_outline,
        destructive: true,
      ),
    ];
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => DriveActionSheet(
        title: file.name,
        subtitle: _fileSubtitle(file),
        leadingIcon: _iconForKind(file.kind),
        leadingAccent: _accentForKind(file.kind),
        actions: actions,
      ),
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
        useRootNavigator: true,
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
      await controller.toggleStar(file.id);
    }
  }

  static Future<void> openFolder(
    BuildContext context,
    WidgetRef ref,
    DriveFolder folder, {
    bool allowRename = true,
  }) async {
    final actions = <SheetActionItem>[
      if (folder.shared)
        const SheetActionItem(
          id: 'revoke_share',
          label: 'Revoke share',
          icon: Icons.link_off,
        )
      else
        const SheetActionItem(
          id: 'share',
          label: 'Share',
          icon: Icons.ios_share,
        ),
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
      SheetActionItem(
        id: 'star',
        label: folder.starred ? 'Unstar' : 'Star',
        icon: folder.starred ? Icons.star : Icons.star_border,
      ),
      const SheetActionItem(
        id: 'delete',
        label: 'Delete',
        icon: Icons.delete_outline,
        destructive: true,
      ),
    ];
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => DriveActionSheet(
        title: folder.name,
        subtitle: _folderSubtitle(folder),
        leadingIcon: Icons.folder_outlined,
        leadingAccent: AppColors.warning,
        actions: actions,
      ),
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
        useRootNavigator: true,
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
      final validation = FolderDeleteGuard.validateFolder(
        controller.state,
        folder,
      );
      if (!validation.canDelete) {
        showFolderNotEmptyToast(context);
        return;
      }
      await controller.deleteItems(folderIds: [folder.id]);
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

String _fileSubtitle(DriveFile file) {
  final parts = <String>[
    formatLabel(file),
    formatFileSize(file.size),
    if (formatDate(file.modifiedAt).isNotEmpty) formatDate(file.modifiedAt),
  ];
  return parts.join(' · ');
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
  return parts.join(' · ');
}

IconData _iconForKind(FileKind kind) {
  switch (kind) {
    case FileKind.folder:
      return Icons.folder_outlined;
    case FileKind.pdf:
      return Icons.picture_as_pdf;
    case FileKind.image:
      return Icons.image_outlined;
    case FileKind.video:
      return Icons.play_circle_outline;
    case FileKind.doc:
      return Icons.description_outlined;
    case FileKind.sheet:
      return Icons.table_chart_outlined;
    case FileKind.slides:
      return Icons.slideshow_outlined;
    case FileKind.audio:
      return Icons.audiotrack;
    case FileKind.zip:
      return Icons.folder_zip_outlined;
    case FileKind.code:
      return Icons.code;
    case FileKind.text:
      return Icons.notes;
    case FileKind.other:
      return Icons.insert_drive_file_outlined;
  }
}

Color _accentForKind(FileKind kind) {
  switch (kind) {
    case FileKind.folder:
      return AppColors.warning;
    case FileKind.pdf:
      return const Color(0xFFC5221F);
    case FileKind.image:
      return const Color(0xFFD81B60);
    case FileKind.video:
      return const Color(0xFF7B1FA2);
    case FileKind.doc:
      return const Color(0xFF1A73E8);
    case FileKind.sheet:
      return AppColors.success;
    case FileKind.slides:
      return AppColors.warning;
    case FileKind.audio:
      return const Color(0xFF00ACC1);
    case FileKind.zip:
      return AppColors.warning;
    case FileKind.code:
      return const Color(0xFF0B57D0);
    case FileKind.text:
      return const Color(0xFF6F6F6F);
    case FileKind.other:
      return const Color(0xFF424242);
  }
}
