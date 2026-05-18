import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/drive_models.dart';
import '../../../models/share_models.dart';
import '../../share/components/create_share_sheet.dart';
import '../../share/share_controller.dart';

Future<void> openShareFile(BuildContext context, String fileId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CreateShareSheet(
      items: [ShareItemRequest(type: ShareItemType.file, id: fileId)],
    ),
  );
}

Future<void> openShareFolder(BuildContext context, String folderId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
  final ok = await _confirmRevoke(context, name: file.name);
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(shareControllerProvider).revokeForFile(file.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share link revoked')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not revoke share')),
    );
  }
}

Future<void> revokeFolderShares(
  BuildContext context,
  WidgetRef ref,
  DriveFolder folder,
) async {
  final ok = await _confirmRevoke(context, name: folder.name);
  if (ok != true || !context.mounted) return;
  try {
    await ref.read(shareControllerProvider).revokeForFolder(folder.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share link revoked')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not revoke share')),
    );
  }
}

Future<bool?> _confirmRevoke(BuildContext context, {required String name}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Revoke share?'),
      content: Text(
        'Existing links to "$name" will stop working immediately.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Revoke'),
        ),
      ],
    ),
  );
}
