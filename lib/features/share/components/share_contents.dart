import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../models/share_models.dart';

/// Browses the snapshot returned by the share API, on both mobile platforms.
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
    final parent = _trail.isEmpty ? null : _trail.last.publicId;
    final items =
        widget.share.items
            .where((item) => item.parentPublicId == parent)
            .toList()
          ..sort((a, b) {
            if (a.kind != b.kind)
              return a.kind == ShareItemType.folder ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    if (widget.share.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Shared contents', style: theme.textTheme.titleMedium),
        if (_trail.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _trail.removeLast()),
              icon: const Icon(CupertinoIcons.chevron_left),
              label: Text(_trail.last.name),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('This folder is empty.'),
          ),
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.kind == ShareItemType.folder
                  ? CupertinoIcons.folder
                  : CupertinoIcons.doc,
            ),
            title: Text(item.name),
            subtitle: Text(
              item.kind == ShareItemType.folder
                  ? 'Folder'
                  : [
                      if (item.mimeType != null) item.mimeType!,
                      if (item.sizeBytes != null) '${item.sizeBytes} bytes',
                      item.relativePath,
                    ].join(' · '),
            ),
            trailing: item.kind == ShareItemType.folder
                ? const Icon(CupertinoIcons.chevron_right, size: 18)
                : null,
            onTap: item.kind == ShareItemType.folder
                ? () => setState(() => _trail.add(item))
                : null,
          ),
      ],
    );
  }
}
