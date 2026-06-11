import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_thumb.dart';
import '../drive/components/drive_dialogs.dart';
import '../drive/components/selection_mode_mixin.dart';
import '../drive/drive_controller.dart';

enum ShelfKind { archive, locked }

class ShelfScreen extends ConsumerStatefulWidget {
  const ShelfScreen({required this.kind, super.key});

  final ShelfKind kind;

  @override
  ConsumerState<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends ConsumerState<ShelfScreen>
    with SelectionModeMixin<ShelfScreen> {
  bool _loading = true;
  List<DriveFile> _files = const [];
  String? _error;
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool showSpinner = true}) {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadShelf(showSpinner: showSpinner);
    _loadFuture = future;
    future.whenComplete(() {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
      }
    });
    return future;
  }

  Future<void> _loadShelf({required bool showSpinner}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (_error != null) {
      setState(() => _error = null);
    }
    try {
      final repo = ref.read(driveRepositoryProvider);
      final files = widget.kind == ShelfKind.archive
          ? await repo.listArchiveFiles()
          : await repo.listLockedFiles();
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      final fallback = widget.kind == ShelfKind.archive
          ? 'Could not load Archive.'
          : 'Could not load Locked.';
      final message = ref
          .read(driveRepositoryProvider)
          .api
          .errorMessage(err, fallback);
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  String get _title => widget.kind == ShelfKind.archive ? 'Archive' : 'Locked';

  String get _emptyTitle =>
      widget.kind == ShelfKind.archive ? 'Archive is empty' : 'Nothing locked';

  String get _emptyBody => widget.kind == ShelfKind.archive
      ? 'Items you archive will appear here so they stay out of your main Drive.'
      : 'Items you lock will appear here so they stay out of your main Drive.';

  String get _footerCaption => widget.kind == ShelfKind.archive
      ? 'These items are hidden from the main drive until you unarchive them.'
      : 'These items are hidden from the main drive until you unlock them.';

  IconData get _emptyIcon => widget.kind == ShelfKind.archive
      ? Icons.inventory_2_outlined
      : Icons.lock_outline_rounded;

  IconData get _restoreIcon => widget.kind == ShelfKind.archive
      ? Icons.unarchive_outlined
      : Icons.lock_open_outlined;

  String get _restoreTooltip =>
      widget.kind == ShelfKind.archive ? 'Unarchive' : 'Unlock';

  Future<void> _restoreOne(String id) async {
    final controller = ref.read(driveControllerProvider);
    final match = _files.where((f) => f.id == id).toList();
    final origin = match.isEmpty ? null : match.first.parentId;
    setState(() => _files = _files.where((f) => f.id != id).toList());
    try {
      if (widget.kind == ShelfKind.archive) {
        await controller.unarchiveFile(id, originFolderId: origin);
      } else {
        await controller.unlockFile(id, originFolderId: origin);
      }
    } catch (_) {
      if (mounted) await _load(showSpinner: false);
    }
  }

  Future<void> _trashOne(String id) async {
    final ok = await confirmDelete(context, 1, trashEnabled: true);
    if (!ok || !mounted) return;
    final controller = ref.read(driveControllerProvider);
    setState(() => _files = _files.where((f) => f.id != id).toList());
    try {
      await controller.deleteItems(fileIds: [id]);
    } catch (_) {
      if (mounted) await _load(showSpinner: false);
    }
  }

  Future<void> _bulkRestore() async {
    final controller = ref.read(driveControllerProvider);
    final idSet = selectedFileIds.toSet();
    final files = _files.where((f) => idSet.contains(f.id)).toList();
    exitSelect();
    setState(() => _files = _files.where((f) => !idSet.contains(f.id)).toList());
    try {
      for (final file in files) {
        if (widget.kind == ShelfKind.archive) {
          await controller.unarchiveFile(file.id, originFolderId: file.parentId);
        } else {
          await controller.unlockFile(file.id, originFolderId: file.parentId);
        }
      }
    } catch (_) {
      if (mounted) await _load(showSpinner: false);
    }
  }

  Future<void> _bulkTrash() async {
    final ok = await confirmDelete(context, selectedCount, trashEnabled: true);
    if (!ok || !mounted) return;
    final controller = ref.read(driveControllerProvider);
    final ids = selectedFileIds.toList();
    final idSet = ids.toSet();
    exitSelect();
    setState(() => _files = _files.where((f) => !idSet.contains(f.id)).toList());
    try {
      await controller.deleteItems(fileIds: ids);
    } catch (_) {
      if (mounted) await _load(showSpinner: false);
    }
  }

  bool _isFileSelected(String id) => selectedFileIds.contains(id);

  int _shelfRevision(DriveState state) => widget.kind == ShelfKind.archive
      ? state.archiveRevision
      : state.lockedRevision;

  @override
  Widget build(BuildContext context) {
    ref.listen<DriveController>(driveControllerProvider, (previous, next) {
      if (previous == null) return;
      if (_shelfRevision(previous.state) == _shelfRevision(next.state)) return;
      unawaited(_load(showSpinner: false));
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = !_loading && _error == null && _files.isEmpty;

    return Scaffold(
      appBar: selectMode
          ? _buildSelectionAppBar(context)
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
              title: Text(_title),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context, theme, scheme, empty),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSelection = selectedCount > 0;
    return AppBar(
      backgroundColor: scheme.surfaceContainer,
      leading: IconButton(
        tooltip: 'Cancel',
        icon: const Icon(Icons.close_rounded),
        onPressed: exitSelect,
      ),
      title: Text(hasSelection ? '$selectedCount selected' : 'Select items'),
      actions: [
        IconButton(
          tooltip: _restoreTooltip,
          icon: Icon(_restoreIcon),
          onPressed: hasSelection ? _bulkRestore : null,
        ),
        IconButton(
          tooltip: 'Move to Trash',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: hasSelection ? _bulkTrash : null,
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    bool empty,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [Text(_error!, style: TextStyle(color: scheme.error))],
      );
    }
    if (empty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: EmptyState(
              icon: _emptyIcon,
              title: _emptyTitle,
              body: _emptyBody,
            ),
          ),
        ],
      );
    }

    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.35);
    final tiles = <Widget>[];

    Widget divider() => Divider(
      color: dividerColor,
      height: 1,
      thickness: 1,
      indent: AppSpacing.md + 36,
    );

    for (var i = 0; i < _files.length; i++) {
      final file = _files[i];
      tiles.add(
        _ShelfTile(
          key: ValueKey('file-${file.id}'),
          title: file.name,
          subtitle: formatFileSize(file.size),
          file: file,
          selectMode: selectMode,
          selected: _isFileSelected(file.id),
          onTap: () => toggleFileSelection(file.id),
          onLongPress: () => enterSelect(fileId: file.id),
          onRestore: () => _restoreOne(file.id),
          onTrash: () => _trashOne(file.id),
          restoreIcon: _restoreIcon,
          restoreTooltip: _restoreTooltip,
        ),
      );
      if (i < _files.length - 1) tiles.add(divider());
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Text(
            _footerCaption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        ...tiles,
      ],
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({
    required this.title,
    required this.subtitle,
    required this.file,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onRestore,
    required this.onTrash,
    required this.restoreIcon,
    required this.restoreTooltip,
    super.key,
  });

  final String title;
  final String subtitle;
  final DriveFile file;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRestore;
  final VoidCallback onTrash;
  final IconData restoreIcon;
  final String restoreTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: selectMode
                    ? Center(
                        child: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          size: 22,
                        ),
                      )
                    : MediaThumb(
                        file: file,
                        fit: BoxFit.cover,
                        radius: AppRadii.sm,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (!selectMode) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  tooltip: restoreTooltip,
                  onPressed: onRestore,
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  color: scheme.onSurfaceVariant,
                  icon: Icon(restoreIcon),
                ),
                IconButton(
                  tooltip: 'Move to Trash',
                  onPressed: onTrash,
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  color: scheme.onSurfaceVariant,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

