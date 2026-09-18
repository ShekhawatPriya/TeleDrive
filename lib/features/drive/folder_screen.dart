import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/safe_navigation.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios_more_menu.dart';
import '../../widgets/skeletons.dart';

import '../upload/ui/components/bottom_action_system.dart';
import 'components/drive_item_actions.dart';
import 'components/drive_list_slivers.dart';
import 'components/drive_menu_builder.dart';
import 'components/drive_selection_bar.dart';
import 'components/selection_mode_mixin.dart';
import 'drive_controller.dart';
import 'view_preferences_controller.dart';
import 'virtual_sections.dart';

class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({required this.folderId, super.key});
  final String folderId;

  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen>
    with SelectionModeMixin<FolderScreen> {
  List<DriveFile>? _sortedFiles;
  ({List<DriveFile> source, SortField sort, bool ascending, String? folderId})?
  _sortedFilesKey;
  List<DriveFolder>? _sortedFolders;
  ({List<DriveFolder> source, bool ascending, String? folderId})?
  _sortedFoldersKey;

  List<DriveFile> _memoSortedFiles({
    required List<DriveFile> source,
    required SortField sort,
    required bool ascending,
  }) {
    final key = (
      source: source,
      sort: sort,
      ascending: ascending,
      folderId: widget.folderId,
    );
    if (_sortedFilesKey == key && _sortedFiles != null) return _sortedFiles!;
    final sorted = sortDriveFiles(source, sort: sort, ascending: ascending);
    _sortedFilesKey = key;
    _sortedFiles = sorted;
    return sorted;
  }

  List<DriveFolder> _memoSortedFolders({
    required List<DriveFolder> source,
    required bool ascending,
  }) {
    final key = (
      source: source,
      ascending: ascending,
      folderId: widget.folderId,
    );
    if (_sortedFoldersKey == key && _sortedFolders != null) {
      return _sortedFolders!;
    }
    final sorted = sortDriveFolders(source, ascending: ascending);
    _sortedFoldersKey = key;
    _sortedFolders = sorted;
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(driveControllerProvider).setActiveFolderId(widget.folderId);
    });
  }

  @override
  void didUpdateWidget(covariant FolderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folderId != widget.folderId) {
      ref.read(driveControllerProvider).setActiveFolderId(widget.folderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      driveControllerProvider.select(
        (c) => c.folderViewSnapshot(widget.folderId),
      ),
    );
    final prefs = ref.watch(viewPreferencesProvider);
    final folder = snapshot.folder;
    var folders = hideVirtualSectionFolders(snapshot.folders);
    folders = _memoSortedFolders(source: folders, ascending: prefs.ascending);
    final files = _memoSortedFiles(
      source: snapshot.files,
      sort: prefs.sort,
      ascending: prefs.ascending,
    );
    final path = snapshot.path;
    final grid = prefs.layout == LayoutMode.grid;
    final loaded = snapshot.loaded;
    final loading = snapshot.loading;
    final hasMore = snapshot.hasMore;
    final loadingMore = snapshot.loadingMore;
    // Deep link / G4: if metadata isn't in _folderById yet but the page is
    // still loading, show "Loading folder…" rather than the placeholder
    // "Folder" — once the children request returns with the path, the title
    // resolves automatically.
    final title = folder?.name ?? (loaded ? 'Folder' : 'Loading folder…');

    return Scaffold(
      appBar: selectMode
          ? PreferredSize(
              preferredSize: Size.fromHeight(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? ((MediaQuery.textScalerOf(context).scale(17) > 24 ||
                              MediaQuery.sizeOf(context).width < 360)
                          ? 112
                          : 56)
                    : 64,
              ),
              child: DriveSelectionBar(
                selectedCount: selectedCount,
                onSelectAll: () => selectAllItems(files, folders),
                onClear: clearSelection,
                onCancel: exitSelect,
                onShare: () => bulkShare(context),
                onStar: bulkStar,
                onMove: () =>
                    bulkMove(context, currentParentId: widget.folderId),
                onDelete: () => bulkDelete(context),
              ),
            )
          : AppBar(
              title: Text(title),
              actions: [
                IosMoreButton(
                  sectionsBuilder: (ctx) => buildDriveMenuSections(
                    ctx,
                    ref,
                    folderId: widget.folderId,
                    includeLayoutSection: true,
                    onSelect: () => setState(() => selectMode = true),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref
                .read(driveControllerProvider)
                .refreshFolder(widget.folderId, silent: false),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 200 &&
                    hasMore &&
                    !loadingMore) {
                  ref
                      .read(driveControllerProvider)
                      .loadMoreFolder(widget.folderId);
                }
                return false;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _Breadcrumbs(path: path)),
                  if (!loaded && loading)
                    const SliverFillRemaining(child: SkeletonList()),
                  if (loaded && folders.isEmpty && files.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.folder_open,
                        title: 'Nothing here yet',
                        body: 'Upload files or create a nested folder.',
                      ),
                    ),
                  DriveFolderSliver(
                    allowRename: false,
                    folders: folders,
                    selectMode: selectMode,
                    selectedFolderIds: selectedFolderIds,
                    onFolderTap: _onFolderTap,
                    onFolderLongPress: (id) => enterSelect(folderId: id),
                    onFolderMore: (f) => DriveItemActions.openFolder(
                      context,
                      ref,
                      f,
                      allowRename: false,
                    ),
                  ),
                  DriveFilesSliver(
                    files: files,
                    grid: grid,
                    selectMode: selectMode,
                    selectedFileIds: selectedFileIds,
                    onFileTap: _onFileTap,
                    onFileLongPress: (id) => enterSelect(fileId: id),
                    onFileMore: (f) =>
                        DriveItemActions.openFile(context, ref, f),
                    bottomPadding: 150,
                  ),
                  if (loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (selectMode && Theme.of(context).platform == TargetPlatform.iOS)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DriveSelectionBar(
                actionsOnly: true,
                selectedCount: selectedCount,
                onSelectAll: () => selectAllItems(files, folders),
                onClear: clearSelection,
                onCancel: exitSelect,
                onShare: () => bulkShare(context),
                onStar: bulkStar,
                onMove: () =>
                    bulkMove(context, currentParentId: widget.folderId),
                onDelete: () => bulkDelete(context),
              ),
            ),
          if (!(selectMode && Theme.of(context).platform == TargetPlatform.iOS))
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: BottomActionSystem(
                  showFab: !selectMode,
                  parentId: widget.folderId,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onFileTap(DriveFile file) {
    if (selectMode) {
      toggleFileSelection(file.id);
      return;
    }
    openDriveFile(context, ref, file);
  }

  void _onFolderTap(DriveFolder folder) {
    if (selectMode) {
      toggleFolderSelection(folder.id);
      return;
    }
    context.safePush('/folder/${folder.id}');
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.path});
  final List<dynamic> path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: path.length,
        separatorBuilder: (_, __) => Center(
          child: Icon(
            Icons.chevron_right,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
        itemBuilder: (_, i) {
          final isLast = i == path.length - 1;
          return Center(
            child: TextButton(
              onPressed: isLast
                  ? null
                  : () => context.safePush('/folder/${path[i].id}'),
              style: TextButton.styleFrom(
                foregroundColor: isLast ? scheme.onSurface : scheme.primary,
              ),
              child: Text(path[i].name as String),
            ),
          );
        },
      ),
    );
  }
}
