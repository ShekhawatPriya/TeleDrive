import 'package:flutter/material.dart';

/// Prompts the user for a new folder name and returns the trimmed value
/// (or null if cancelled / left blank).
Future<String?> promptFolderName(
  BuildContext context, {
  String title = 'New folder',
  String? initial,
  String confirmLabel = 'Create',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Folder name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (result == null || result.isEmpty) return null;
  return result;
}

Future<bool> confirmDelete(BuildContext context, int count) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Move to trash?'),
      content: Text('$count items will be moved to trash.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result == true;
}
