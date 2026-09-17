import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/sheet/ios_action_group.dart';
import 'drive_sheet_action.dart';

/// Identity first, frequent actions second, organization and deletion last.
/// Action IDs still return through the existing route contract.
class IosItemActions extends StatelessWidget {
  const IosItemActions({
    required this.title,
    required this.actions,
    this.subtitle,
    this.folder,
    this.preview,
    super.key,
  });
  final String title;
  final String? subtitle;
  final DriveFolder? folder;
  final Widget? preview;
  final List<SheetActionItem> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const quickIds = {'share', 'revoke_share', 'download', 'star', 'unstar'};
    final quick = actions
        .where((a) => quickIds.contains(a.id) && !a.destructive)
        .toList();
    final organize = actions
        .where((a) => !quickIds.contains(a.id) && !a.destructive)
        .toList();
    final destructive = actions.where((a) => a.destructive).toList();
    void choose(SheetActionItem item) => Navigator.pop(context, item.id);
    final details = folder == null
        ? subtitle
        : folder!.isOptimistic
        ? 'Creating folder…'
        : '${folder!.recursiveFileCount} ${folder!.recursiveFileCount == 1 ? 'file' : 'files'} · ${formatFileSize(folder!.recursiveSize)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            child: Row(
              children: [
                if (folder != null || preview != null) ...[
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: folder != null
                        ? Icon(
                            CupertinoIcons.folder_fill,
                            size: 32,
                            color: scheme.primary,
                          )
                        : ClipRSuperellipse(
                            borderRadius: BorderRadius.circular(10),
                            child: preview,
                          ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (details != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          details,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => Navigator.pop(context),
                  child: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    semanticLabel: 'Close actions',
                    size: 24,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final group in [quick, organize, destructive])
            if (group.isNotEmpty)
              IosActionGroup(
                children: [
                  for (final action in group)
                    IosActionRow(
                      label: action.label,
                      icon: _actionIcon(action),
                      destructive: action.destructive,
                      onPressed: () => choose(action),
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

IconData _actionIcon(SheetActionItem action) => switch (action.id) {
  'share' => CupertinoIcons.square_arrow_up,
  'revoke_share' => CupertinoIcons.link,
  'download' => CupertinoIcons.arrow_down_to_line,
  'rename' => CupertinoIcons.pencil,
  'move' => CupertinoIcons.folder,
  'lock' => CupertinoIcons.lock,
  'archive' => CupertinoIcons.archivebox,
  'star' => CupertinoIcons.star,
  'unstar' => CupertinoIcons.star_fill,
  'delete' => CupertinoIcons.trash,
  _ => action.icon,
};
