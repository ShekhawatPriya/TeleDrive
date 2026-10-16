import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One editor for create and rename, with platform-specific input and actions.
class FolderEditor extends StatefulWidget {
  const FolderEditor({
    required this.title,
    required this.confirmLabel,
    this.initial,
    super.key,
  });
  final String title;
  final String confirmLabel;
  final String? initial;

  @override
  State<FolderEditor> createState() => _FolderEditorState();
}

class _FolderEditorState extends State<FolderEditor> {
  late final TextEditingController _name;
  bool get _valid => _name.text.trim().isNotEmpty;
  bool get _renaming => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial);
    if (_renaming)
      _name.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _name.text.length,
      );
    _name.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _name.removeListener(_changed);
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_valid) return;
    HapticFeedback.selectionClick();
    Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final input = ios
        ? CupertinoTextField(
            key: const ValueKey('folder-name'),
            controller: _name,
            autofocus: true,
            placeholder: 'Folder name',
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            clearButtonMode: OverlayVisibilityMode.editing,
            onSubmitted: (_) => _submit(),
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            padding: const EdgeInsets.all(16),
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
            placeholderStyle: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
          )
        : TextField(
            key: const ValueKey('folder-name'),
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: InputDecoration(
              labelText: 'Folder name',
              hintText: 'e.g. Weekend plans',
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              suffixIcon: _name.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear name',
                      onPressed: _name.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(ios ? 8 : 24, 0, ios ? 8 : 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ios)
              // Notes-style sheet bar: Cancel, centered title, bold confirm.
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(64, 44),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          _titleCase(widget.title),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(64, 44),
                      onPressed: _valid ? _submit : null,
                      child: Text(
                        widget.confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: ios
                            ? theme.textTheme.titleMedium?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              )
                            : theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  if (!ios)
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            if (!ios)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: ShapeDecoration(
                  color: scheme.primary.withValues(alpha: .07),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded, size: 56, color: scheme.primary),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _valid ? _name.text.trim() : 'Untitled folder',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _renaming ? 'Rename folder' : 'New folder',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (!ios) const SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ios ? 12 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: 'Folder name',
                    textField: true,
                    child: input,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _renaming
                        ? 'Your files and sharing settings stay the same.'
                        : 'You can move or rename this folder anytime.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (ios)
              const SizedBox(height: 8)
            else ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: _valid ? _submit : null,
                      icon: Icon(
                        _renaming
                            ? Icons.check_rounded
                            : Icons.create_new_folder_outlined,
                      ),
                      label: Text(widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// iOS sheet titles use title case ("New Folder", "Rename Folder").
String _titleCase(String value) => value
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');
