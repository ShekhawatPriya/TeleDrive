import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../widgets/sheet/adaptive_sheet.dart';
import 'folder_editor.dart';

/// Prompts for a new folder name. Returns the trimmed value, or null if
/// cancelled / left blank.
Future<String?> promptFolderName(
  BuildContext context, {
  String title = 'New folder',
  String? initial,
  String confirmLabel = 'Create',
}) {
  return showAdaptiveSheet<String>(
    context: context,
    builder: (_) => FolderEditor(
      title: title,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

/// Confirmation dialog. Returns true when the user taps the confirm button.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      if (Theme.of(ctx).platform == TargetPlatform.iOS) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      }
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: scheme.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}

Future<bool> confirmDelete(
  BuildContext context,
  int count, {
  bool trashEnabled = true,
}) {
  return confirmAction(
    context,
    title: trashEnabled ? 'Move to Trash?' : 'Delete forever?',
    message: trashEnabled
        ? (count == 1
              ? '1 item will be moved to Trash. You can restore it later.'
              : '$count items will be moved to Trash. You can restore them later.')
        : (count == 1
              ? '1 item will be permanently deleted from Telegram storage and this database.'
              : '$count items will be permanently deleted from Telegram storage and this database.'),
    confirmLabel: trashEnabled ? 'Move to Trash' : 'Delete forever',
    destructive: true,
  );
}
