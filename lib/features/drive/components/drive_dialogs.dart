import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prompts for a new folder name. Returns the trimmed value, or null if
/// cancelled / left blank.
Future<String?> promptFolderName(
  BuildContext context, {
  String title = 'New folder',
  String? initial,
  String confirmLabel = 'Create',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FolderNameDialog(
      title: title,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
  });

  final String title;
  final String? initial;
  final String confirmLabel;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        inputFormatters: [LengthLimitingTextInputFormatter(120)],
        decoration: const InputDecoration(
          labelText: 'Folder name',
          prefixIcon: Icon(Icons.folder_outlined),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
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
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
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

Future<bool> confirmDelete(BuildContext context, int count) {
  return confirmAction(
    context,
    title: 'Move to trash?',
    message: count == 1
        ? '1 item will be moved to trash. You can restore it later.'
        : '$count items will be moved to trash. You can restore them later.',
    confirmLabel: 'Delete',
    destructive: true,
  );
}
