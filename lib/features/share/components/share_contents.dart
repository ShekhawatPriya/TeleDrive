import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/share_models.dart';

/// Browses the API snapshot, with a separate parent action and current path.
class ShareContents extends StatefulWidget {
  const ShareContents({required this.share, super.key});
  final Share share;
  @override
  State<ShareContents> createState() => _ShareContentsState();
}

class _ShareContentsState extends State<ShareContents> {
  final List<ShareItemSummary> _trail = [];
  @override
  void didUpdateWidget(covariant ShareContents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.share.id != widget.share.id) _trail.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final parent = _trail.isEmpty ? null : _trail.last.publicId;
    final items =
        widget.share.items
            .where((item) => item.parentPublicId == parent)
            .toList()
          ..sort(
            (a, b) => a.kind != b.kind
                ? (a.kind == ShareItemType.folder ? -1 : 1)
                : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    if (widget.share.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Shared contents', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 12),
        if (_trail.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: _trail.length == 1
                      ? 'Back to shared contents'
                      : 'Back to ${_trail[_trail.length - 2].name}',
                  onPressed: () => setState(() => _trail.removeLast()),
                  icon: Icon(
                    ios
                        ? CupertinoIcons.chevron_back
                        : Icons.arrow_back_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_trail.last.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      _trail.map((item) => item.name).join(' / '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('This folder is empty.'),
          ),
        for (final item in items) _item(context, item, ios),
      ],
    );
  }

  Widget _item(BuildContext context, ShareItemSummary item, bool ios) {
    final theme = Theme.of(context);
    final folder = item.kind == ShareItemType.folder;
    final details = folder
        ? 'Folder'
        : [
            if (item.mimeType != null) item.mimeType!,
            if (item.sizeBytes != null) formatFileSize(item.sizeBytes!),
          ].join(' · ');
    final slash = item.relativePath.lastIndexOf('/');
    final location = slash < 0 ? null : item.relativePath.substring(0, slash);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              folder
                  ? (ios ? CupertinoIcons.folder : Icons.folder_outlined)
                  : (ios
                        ? CupertinoIcons.doc
                        : Icons.insert_drive_file_outlined),
              color: folder
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(details, style: theme.textTheme.bodySmall),
                if (!folder && location != null) ...[
                  const SizedBox(height: 4),
                  Text(location, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (folder)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: Icon(
                ios
                    ? CupertinoIcons.chevron_forward
                    : Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
    final open = folder ? () => setState(() => _trail.add(item)) : null;
    return ios && folder
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: open,
            child: content,
          )
        : InkWell(onTap: open, child: content);
  }
}
