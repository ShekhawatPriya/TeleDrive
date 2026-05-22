import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../drive/components/drive_dialogs.dart';
import '../drive/components/selection_mode_mixin.dart';
import '../drive/drive_controller.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen>
    with SelectionModeMixin<TrashScreen> {
  bool _loading = true;
  List<DriveFile> _files = const [];
  List<DriveFolder> _folders = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(driveRepositoryProvider);
      final results = await Future.wait([
        repo.listTrashFiles(),
        repo.listTrashFolders(),
      ]);
      if (!mounted) return;
      setState(() {
        _files = results[0] as List<DriveFile>;
        _folders = results[1] as List<DriveFolder>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Trash.';
        _loading = false;
      });
    }
  }

  int get _totalCount => _files.length + _folders.length;

  bool _isFolderSelected(String id) => selectedFolderIds.contains(id);
  bool _isFileSelected(String id) => selectedFileIds.contains(id);

  Future<void> _restoreFile(String id) async {
    await ref.read(driveControllerProvider).restoreFile(id);
    await _load();
  }

  Future<void> _restoreFolder(String id) async {
    await ref.read(driveControllerProvider).restoreFolder(id);
    await _load();
  }

  Future<void> _purgeFile(String id) async {
    final ok = await confirmDelete(context, 1, trashEnabled: false);
    if (!ok || !mounted) return;
    await ref.read(driveControllerProvider).purgeFile(id);
    await _load();
  }

  Future<void> _purgeFolder(String id) async {
    final ok = await confirmDelete(context, 1, trashEnabled: false);
    if (!ok || !mounted) return;
    await ref.read(driveControllerProvider).purgeFolder(id);
    await _load();
  }

  Future<void> _bulkRestore() async {
    final controller = ref.read(driveControllerProvider);
    final folderIds = selectedFolderIds.toList();
    final fileIds = selectedFileIds.toList();
    await Future.wait([
      ...folderIds.map(controller.restoreFolder),
      ...fileIds.map(controller.restoreFile),
    ]);
    if (!mounted) return;
    exitSelect();
    await _load();
  }

  Future<void> _bulkPurge() async {
    final ok = await confirmDelete(context, selectedCount, trashEnabled: false);
    if (!ok || !mounted) return;
    final controller = ref.read(driveControllerProvider);
    final folderIds = selectedFolderIds.toList();
    final fileIds = selectedFileIds.toList();
    await Future.wait([
      ...folderIds.map(controller.purgeFolder),
      ...fileIds.map(controller.purgeFile),
    ]);
    if (!mounted) return;
    exitSelect();
    await _load();
  }

  Future<void> _purgeAll() async {
    final ok = await confirmDelete(context, _totalCount, trashEnabled: false);
    if (!ok || !mounted) return;
    await ref.read(driveControllerProvider).purgeAllTrash();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = !_loading && _error == null && _totalCount == 0;
    final showDeleteAll =
        !selectMode && !_loading && _error == null && _totalCount > 0;

    return Scaffold(
      appBar: selectMode
          ? _buildSelectionAppBar(context)
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
              title: const Text('Trash'),
              actions: [
                if (showDeleteAll)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: TextButton(
                      onPressed: _purgeAll,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                      child: const Text('Delete all'),
                    ),
                  ),
              ],
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
          tooltip: 'Restore',
          icon: const Icon(Icons.restore_rounded),
          onPressed: hasSelection ? _bulkRestore : null,
        ),
        IconButton(
          tooltip: 'Delete forever',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: hasSelection ? _bulkPurge : null,
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
            child: const EmptyState(
              icon: Icons.delete_sweep_outlined,
              title: 'Trash is empty',
              body:
                  'Items you delete will appear here so you can restore them before they are removed forever.',
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

    for (var i = 0; i < _folders.length; i++) {
      final folder = _folders[i];
      tiles.add(
        _TrashTile(
          key: ValueKey('folder-${folder.id}'),
          title: folder.name,
          subtitle: '${folder.recursiveFileCount} items',
          icon: Icons.folder_outlined,
          selectMode: selectMode,
          selected: _isFolderSelected(folder.id),
          onTap: () => toggleFolderSelection(folder.id),
          onLongPress: () => enterSelect(folderId: folder.id),
          onRestore: () => _restoreFolder(folder.id),
          onPurge: () => _purgeFolder(folder.id),
        ),
      );
      tiles.add(divider());
    }
    for (var i = 0; i < _files.length; i++) {
      final file = _files[i];
      tiles.add(
        _TrashTile(
          key: ValueKey('file-${file.id}'),
          title: file.name,
          subtitle: formatFileSize(file.size),
          icon: _fileIcon(file.kind),
          selectMode: selectMode,
          selected: _isFileSelected(file.id),
          onTap: () => toggleFileSelection(file.id),
          onLongPress: () => enterSelect(fileId: file.id),
          onRestore: () => _restoreFile(file.id),
          onPurge: () => _purgeFile(file.id),
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
            'Items here still exist in Telegram storage until you delete them forever.',
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

class _TrashTile extends StatelessWidget {
  const _TrashTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onRestore,
    required this.onPurge,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

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
                    : Center(
                        child: Icon(icon, color: scheme.primary, size: 24),
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
                  tooltip: 'Restore',
                  onPressed: onRestore,
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  color: scheme.onSurfaceVariant,
                  icon: const Icon(Icons.restore_rounded),
                ),
                IconButton(
                  tooltip: 'Delete forever',
                  onPressed: onPurge,
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

IconData _fileIcon(FileKind kind) {
  return switch (kind) {
    FileKind.image => Icons.image_outlined,
    FileKind.video => Icons.play_circle_outline,
    FileKind.audio => Icons.audiotrack,
    FileKind.pdf => Icons.picture_as_pdf,
    FileKind.folder => Icons.folder_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}
