import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/drive_models.dart';
import '../../share/share_flow.dart';
import '../drive_controller.dart';
import '../../share/share_controller.dart';
import 'drive_dialogs.dart';

Future<void> openShareFile(
  BuildContext context,
  WidgetRef ref,
  DriveFile file,
) => openItemShare(context, ref, files: [file]);

Future<void> openShareFolder(
  BuildContext context,
  WidgetRef ref,
  String folderId,
) => openItemShare(context, ref, files: const [], folderIds: {folderId});

Future<void> openShareSelection(
  BuildContext context,
  WidgetRef ref, {
  required Set<String> fileIds,
  required Set<String> folderIds,
}) async {
  final drive = ref.read(driveControllerProvider);
  final files = <DriveFile>[];
  for (final id in fileIds) {
    final file = drive.file(id);
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some selected files are no longer available. Select them again.',
          ),
        ),
      );
      return;
    }
    files.add(file);
  }
  await openItemShare(context, ref, files: files, folderIds: folderIds);
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
