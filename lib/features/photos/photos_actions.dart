import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/drive_models.dart';
import '../drive/components/drive_item_actions.dart';
import '../drive/drive_controller.dart';

/// Shared bulk-action helpers for the Photos screen.  Move and Delete delegate
/// to [DriveBulkActions] so the implementation stays in one place; Share is
/// Photos-specific because it ships the public stream/download URL of each
/// item to the system share sheet.
class PhotosActions {
  PhotosActions._();

  static Future<void> share(
    BuildContext context,
    WidgetRef ref, {
    required Set<String> fileIds,
  }) async {
    if (fileIds.isEmpty) return;
    final controller = ref.read(driveControllerProvider);
    final files = <DriveFile>[
      for (final id in fileIds)
        if (controller.file(id) != null) controller.file(id)!,
    ];
    if (files.isEmpty) return;

    final urls = <String>[
      for (final f in files)
        if (_shareTarget(f) != null) _shareTarget(f)!,
    ];
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to share — links not yet available.'),
        ),
      );
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? Rect.zero
        : box.localToGlobal(Offset.zero) & box.size;
    final subject = files.length == 1
        ? files.first.name
        : '${files.length} items from TeleDrive';
    await Share.share(
      urls.join('\n'),
      subject: subject,
      sharePositionOrigin: origin,
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

  static String? _shareTarget(DriveFile file) {
    return file.streamUrl ?? file.downloadUrl ?? file.previewUrl ?? file.localUri;
  }
}
