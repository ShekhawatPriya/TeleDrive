import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/drive_models.dart';
import '../../widgets/sheet/sheet_header.dart';
import 'drive_controller.dart';
import 'virtual_sections.dart';

const rootMoveDestination = '__teledrive_root__';

/// Lazy level-by-level folder browser used to pick a move destination.
///
/// After the on-demand Drive refactor, `_folderById` is intentionally
/// incomplete — only folders the user has visited live there. A recursive
/// tree built from that map would silently hide unvisited branches, so the
/// sheet now fetches one level at a time via `/folders/children` (the same
/// endpoint folder views use).
///
/// Cycle detection (moving a folder into its own descendant) lives on the
/// backend (`assert_can_move_folder`); the picker excludes only the moving
/// folder itself, surfaces server-side errors inline.
class MoveDestinationSheet extends ConsumerStatefulWidget {
  const MoveDestinationSheet({
    required this.title,
    this.movingFolderId,
    this.currentParentId,
    super.key,
  });

  final String title;
  final String? movingFolderId;
  final String? currentParentId;

  @override
  ConsumerState<MoveDestinationSheet> createState() =>
      _MoveDestinationSheetState();
}

class _LevelState {
  _LevelState({this.folder});
  DriveFolder? folder;
  List<DriveFolder> children = const [];
  bool loaded = false;
  bool loading = false;
  String? error;
  String? cursor;
}

class _MoveDestinationSheetState extends ConsumerState<MoveDestinationSheet> {
  /// Stack of levels the user has descended into. The first element is always
  /// the root level (folder=null). Tapping a folder pushes a level; the back
  /// button pops one.
  final List<_LevelState> _stack = [_LevelState()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLevel(_stack.last);
    });
  }

  Future<void> _loadLevel(_LevelState level, {bool loadMore = false}) async {
    if (level.loading) return;
    if (loadMore && level.cursor == null) return;
    setState(() {
      level.loading = true;
      level.error = null;
    });
    try {
      final repo = ref.read(driveRepositoryProvider);
      final result = await repo.listFolderChildren(
        parentId: level.folder?.id,
        limit: 100,
        cursor: loadMore ? level.cursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          final existing = level.children.map((f) => f.id).toSet();
          level.children = [
            ...level.children,
            ...result.folders.where((f) => !existing.contains(f.id)),
          ];
        } else {
          level.children = result.folders;
        }
        level.cursor = result.nextCursor;
        level.loaded = true;
        level.loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        level.loading = false;
        level.error = 'Could not load folders.';
      });
    }
  }

  void _enterFolder(DriveFolder folder) {
    final movingId = widget.movingFolderId;
    if (movingId != null && folder.id == movingId) return;
    final next = _LevelState(folder: folder);
    setState(() => _stack.add(next));
    _loadLevel(next);
  }

  void _popLevel() {
    if (_stack.length <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() => _stack.removeLast());
  }

  String _breadcrumb() {
    if (_stack.length == 1) return 'My Drive';
    return ['My Drive', ..._stack.skip(1).map((l) => l.folder?.name ?? '')]
        .join(' › ');
  }

  bool _canChooseCurrent() {
    final current = _stack.last;
    final currentId = current.folder?.id;
    if (currentId == widget.currentParentId) return false;
    if (currentId != null && currentId == widget.movingFolderId) return false;
    return true;
  }

  void _chooseCurrent() {
    final current = _stack.last;
    if (current.folder == null) {
      Navigator.pop(context, rootMoveDestination);
    } else {
      Navigator.pop(context, current.folder!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = _stack.last;
    final visibleChildren = level.children
        .where((f) => !isVirtualSectionFolder(f))
        .where((f) => f.id != widget.movingFolderId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .35,
        maxChildSize: .9,
        builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              title: widget.title,
              leadingIcon: Icons.drive_file_move_outlined,
              leadingAccent: scheme.primary,
              trailing: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (_stack.length > 1)
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _popLevel,
                    ),
                  Expanded(
                    child: Text(
                      _breadcrumb(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _canChooseCurrent() ? _chooseCurrent : null,
                    child: const Text('Move here'),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100 &&
                      level.cursor != null &&
                      !level.loading) {
                    _loadLevel(level, loadMore: true);
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: controller,
                  itemCount: visibleChildren.length +
                      (level.loading ? 1 : 0) +
                      (level.error != null ? 1 : 0) +
                      (level.loaded && visibleChildren.isEmpty ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (level.error != null && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          level.error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      );
                    }
                    final adj = level.error != null ? index - 1 : index;
                    if (adj < visibleChildren.length) {
                      final folder = visibleChildren[adj];
                      return ListTile(
                        leading: Icon(
                          Icons.folder_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        title: Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _enterFolder(folder),
                      );
                    }
                    if (level.loaded && visibleChildren.isEmpty &&
                        adj == visibleChildren.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Text('No subfolders.'),
                      );
                    }
                    if (level.loading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
