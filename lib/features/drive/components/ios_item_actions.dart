import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(alpha: .13),
                        scheme.primary.withValues(alpha: .035),
                      ],
                    ),
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: folder != null ? const _FolderEmblem() : preview,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder != null ? 'FOLDER' : 'FILE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.2,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 23,
                            letterSpacing: -.6,
                          ),
                        ),
                        if (details != null) ...[
                          const SizedBox(height: 5),
                          Text(details, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => Navigator.pop(context),
                  child: Semantics(
                    label: 'Close actions',
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: .055),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            if (quick.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      MediaQuery.textScalerOf(context).scale(15) > 23
                      ? 1
                      : quick.length.clamp(1, 3);
                  final width =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final action in quick)
                        SizedBox(
                          width: width,
                          child: _Shortcut(
                            action: action,
                            prominent: action.id == 'share',
                            onPressed: () => choose(action),
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (organize.isNotEmpty) ...[
              const SizedBox(height: 22),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: scheme.surfaceContainerLow.withValues(alpha: .65),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < organize.length; index++) ...[
                      if (index > 0)
                        Divider(
                          height: .5,
                          thickness: .5,
                          indent: 52,
                          color: scheme.outlineVariant.withValues(alpha: .55),
                        ),
                      _ManagementRow(
                        action: organize[index],
                        onPressed: () => choose(organize[index]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (destructive.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final action in destructive)
                _ManagementRow(action: action, onPressed: () => choose(action)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.action,
    required this.prominent,
    required this.onPressed,
  });
  final SheetActionItem action;
  final bool prominent;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = prominent ? scheme.primary : scheme.onSurface;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 17),
        decoration: ShapeDecoration(
          color: prominent
              ? scheme.primary.withValues(alpha: .11)
              : scheme.onSurface.withValues(alpha: .055),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_actionIcon(action), size: 26, color: color),
            const SizedBox(height: 9),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementRow extends StatelessWidget {
  const _ManagementRow({required this.action, required this.onPressed});
  final SheetActionItem action;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = action.destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(_actionIcon(action), color: color, size: 21),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              action.label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontSize: 16,
              ),
            ),
          ),
          if (action.id == 'rename' || action.id == 'move')
            Icon(
              CupertinoIcons.chevron_right,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .7),
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

class _FolderEmblem extends StatelessWidget {
  const _FolderEmblem();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 44,
    height: 38,
    child: CustomPaint(painter: _FolderPainter()),
  );
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final back = Path()
      ..moveTo(3, 2)
      ..lineTo(17, 2)
      ..lineTo(22, 7)
      ..lineTo(40, 7)
      ..quadraticBezierTo(44, 7, 44, 11)
      ..lineTo(44, 31)
      ..quadraticBezierTo(44, 36, 39, 36)
      ..lineTo(5, 36)
      ..quadraticBezierTo(0, 36, 0, 31)
      ..lineTo(0, 6)
      ..quadraticBezierTo(0, 2, 3, 2);
    canvas.drawPath(back, Paint()..color = const Color(0xFF7ABFFF));
    final front = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 13, 44, 24),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      front,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF43A2FF), Color(0xFF0874E8)],
        ).createShader(front.outerRect),
    );
    canvas.drawLine(
      const Offset(5, 14),
      const Offset(39, 14),
      Paint()
        ..color = const Color(0x668ED0FF)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) => false;
}
