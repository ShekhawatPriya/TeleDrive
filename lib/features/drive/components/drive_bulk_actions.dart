import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/share_models.dart';
import '../../../widgets/premium_toast.dart';
import '../../share/components/create_share_sheet.dart';
import '../../profile/app_settings_controller.dart';
import '../drive_controller.dart';
import '../folder_delete_guard.dart';
import '../move_destination_sheet.dart';
import 'drive_dialogs.dart';

/// Bulk-action helpers shared between Drive and Folder screens. Operating
/// on the in-memory selection sets and the [driveControllerProvider].
class DriveBulkActions {
  DriveBulkActions._();

  static Future<void> star(
    WidgetRef ref, {
    required Set<String> fileIds,
    required Set<String> folderIds,
  }) async {
    final controller = ref.read(driveControllerProvider);
    await Future.wait([
      for (final id in fileIds) controller.toggleStar(id),
      for (final id in folderIds) controller.toggleStar(id, folder: true),
    ]);
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
      useRootNavigator: true,
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
      useRootNavigator: true,
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
    final controller = ref.read(driveControllerProvider);
    final trashEnabled = ref
        .read(appSettingsControllerProvider)
        .state
        .trashEnabled;
    if (!trashEnabled) {
      final validation = FolderDeleteGuard.validateFolders(
        controller.state,
        folderIds,
      );
      if (!validation.canDelete) {
        showFolderNotEmptyToast(context);
        return false;
      }
    }

    final total = fileIds.length + folderIds.length;
    final ok = await confirmDelete(context, total, trashEnabled: trashEnabled);
    if (!ok || !context.mounted) return false;
    await controller.deleteItems(
      fileIds: fileIds.toList(),
      folderIds: folderIds.toList(),
    );
    return true;
  }
}

void showFolderNotEmptyToast(BuildContext context) {
  showPremiumToast(
    context,
    title: 'Folder isn’t empty',
    message:
        'Move or delete the files and subfolders inside this folder before deleting it.',
    icon: Icons.info_outline_rounded,
  );
}
