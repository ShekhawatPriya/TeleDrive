import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/share_models.dart';
import '../drive/components/drive_item_actions.dart';
import '../drive/drive_controller.dart';
import '../share/components/create_share_sheet.dart';

/// Shared bulk-action helpers for the Photos screen.  Move and Delete delegate
/// to [DriveBulkActions] so the implementation stays in one place; Share opens
/// the create-share sheet which mints a public link via the backend.
class PhotosActions {
  PhotosActions._();

  static Future<void> share(
    BuildContext context,
    WidgetRef ref, {
    required Set<String> fileIds,
  }) async {
    if (fileIds.isEmpty) return;
    final controller = ref.read(driveControllerProvider);
    final resolved = <String>[
      for (final id in fileIds)
        if (controller.anyFile(id) != null) id,
    ];
    if (resolved.isEmpty) return;
    final items = [
      for (final id in resolved)
        ShareItemRequest(type: ShareItemType.file, id: id),
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
  }) async {
    if (fileIds.isEmpty) return;
    await DriveBulkActions.move(
      context,
      ref,
      fileIds: fileIds,
      folderIds: const {},
    );
  }

  static Future<bool> delete(
    BuildContext context,
    WidgetRef ref, {
    required Set<String> fileIds,
  }) async {
    if (fileIds.isEmpty) return false;
    return DriveBulkActions.delete(
      context,
      ref,
      fileIds: fileIds,
      folderIds: const {},
    );
  }
}
