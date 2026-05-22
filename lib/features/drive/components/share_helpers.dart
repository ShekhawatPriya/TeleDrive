import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/drive_models.dart';
import '../../../models/share_models.dart';
import '../../share/components/create_share_sheet.dart';
import '../../share/share_controller.dart';
import 'drive_dialogs.dart';

Future<void> openShareFile(BuildContext context, String fileId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => CreateShareSheet(
      items: [ShareItemRequest(type: ShareItemType.file, id: fileId)],
    ),
  );
}

Future<void> openShareFolder(BuildContext context, String folderId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => CreateShareSheet(
      items: [
        ShareItemRequest(
          type: ShareItemType.folder,
          id: folderId,
          mode: FolderShareMode.snapshot,
        ),
      ],
    ),
  );
}

Future<void> revokeFileShares(
  BuildContext context,
  WidgetRef ref,
  DriveFile file,
) async {
  final ok = await confirmAction(
    context,
    title: 'Revoke share?',
    message: 'Existing links to "${file.name}" will stop working immediately.',
    confirmLabel: 'Revoke',
  );
  if (!ok || !context.mounted) return;
  try {
    await ref.read(shareControllerProvider).revokeForFile(file.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share link revoked')));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not revoke share')));
  }
}

Future<void> revokeFolderShares(
  BuildContext context,
  WidgetRef ref,
  DriveFolder folder,
) async {
  final ok = await confirmAction(
    context,
    title: 'Revoke share?',
    message:
        'Existing links to "${folder.name}" will stop working immediately.',
    confirmLabel: 'Revoke',
  );
  if (!ok || !context.mounted) return;
  try {
    await ref.read(shareControllerProvider).revokeForFolder(folder.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share link revoked')));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not revoke share')));
  }
}
