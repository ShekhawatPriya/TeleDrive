import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/safe_navigation.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ios/ios_browse.dart';
import '../../widgets/ios/ios_tab_header.dart';
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

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _buildIos(
        context,
        title: title,
        path: path,
        folders: folders,
        files: files,
        grid: grid,
        loaded: loaded,
        loading: loading,
        hasMore: hasMore,
        loadingMore: loadingMore,
      );
    }

    return Scaffold(
      appBar: selectMode
          ? null
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
      body: Column(
        children: [
          if (selectMode)
            DriveSelectionBar(
              selectedCount: selectedCount,
              onSelectAll: () => selectAllItems(files, folders),
              onClear: clearSelection,
              onCancel: exitSelect,
              onShare: () => bulkShare(context),
              onStar: bulkStar,
              onMove: () => bulkMove(context, currentParentId: widget.folderId),
              onDelete: () => bulkDelete(context),
            ),
          Expanded(
            child: Stack(
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
                if (selectMode &&
                    Theme.of(context).platform == TargetPlatform.iOS)
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
                if (!(selectMode &&
                    Theme.of(context).platform == TargetPlatform.iOS))
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
          ),
        ],
      ),
    );
  }

  /// iOS: a large title that collapses into the bar, with the same tiles,
  /// rows and section titles as the Drive home.
  Widget _buildIos(
    BuildContext context, {
    required String title,
    required List<dynamic> path,
    required List<DriveFolder> folders,
    required List<DriveFile> files,
    required bool grid,
    required bool loaded,
    required bool loading,
    required bool hasMore,
    required bool loadingMore,
  }) {
    final drive = ref.read(driveControllerProvider);
    Widget selection({bool actionsOnly = false}) => DriveSelectionBar(
      actionsOnly: actionsOnly,
      selectedCount: selectedCount,
      onSelectAll: () => selectAllItems(files, folders),
      onClear: clearSelection,
      onCancel: exitSelect,
      onShare: () => bulkShare(context),
      onStar: bulkStar,
      onMove: () => bulkMove(context, currentParentId: widget.folderId),
      onDelete: () => bulkDelete(context),
    );
    return Scaffold(
      backgroundColor: IosBrowse.canvas(context),
      body: Column(
        children: [
          if (selectMode) selection(),
          Expanded(
            child: Stack(
              children: [
                IosBrowseCanvas(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 200 &&
                          hasMore &&
                          !loadingMore) {
                        drive.loadMoreFolder(widget.folderId);
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (!selectMode)
                          IosLargeTitleHeader(
                            title: title,
                            leading: IosLargeTitleHeader.backButton(context),
                            trailing: IosMoreButton(
                              claimsTouches: true,
                              size: 44,
                              tooltip: '$title options',
                              sectionsBuilder: (ctx) => buildDriveMenuSections(
                                ctx,
                                ref,
                                folderId: widget.folderId,
                                includeLayoutSection: true,
                                onSelect: () =>
                                    setState(() => selectMode = true),
                              ),
                            ),
                          ),
                        CupertinoSliverRefreshControl(
                          onRefresh: () => drive.refreshFolder(
                            widget.folderId,
                            silent: false,
                          ),
                        ),
                        if (path.length > 1 && !selectMode)
                          SliverToBoxAdapter(child: _Breadcrumbs(path: path)),
                        if (!loaded && loading)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CupertinoActivityIndicator()),
                          ),
                        if (loaded && folders.isEmpty && files.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: IosContentUnavailable(
                              icon: CupertinoIcons.folder,
                              title: 'This folder is empty',
                              body:
                                  'Upload files or create a folder inside it.',
                            ),
                          ),
                        if (folders.isNotEmpty)
                          SliverToBoxAdapter(
                            child: IosSectionTitle(
                              'Folders',
                              top: selectMode ? 16 : 8,
                              bottom: 0,
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
                        if (files.isNotEmpty)
                          SliverToBoxAdapter(
                            child: IosSectionTitle(
                              'Files',
                              top: folders.isEmpty ? (selectMode ? 16 : 8) : 28,
                              bottom: grid ? 0 : 6,
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
                          bottomPadding: loadingMore ? 0 : 150,
                        ),
                        if (loadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(0, 20, 0, 150),
                              child: CupertinoActivityIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (selectMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: selection(actionsOnly: true),
                  )
                else
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: 16,
                    child: SafeArea(
                      top: false,
                      child: BottomActionSystem(
                        showFab: true,
                        parentId: widget.folderId,
                      ),
                    ),
                  ),
              ],
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
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // Ancestors only: the large title already names the current folder.
      final ancestors = path.take(path.length - 1).toList();
      return SizedBox(
        height: 36,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: ancestors.length,
          separatorBuilder: (_, __) => Center(
            child: Icon(
              CupertinoIcons.chevron_right,
              size: 12,
              color: scheme.outline,
            ),
          ),
          itemBuilder: (_, i) => CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 36),
            onPressed: () => context.safePush('/folder/${ancestors[i].id}'),
            child: Text(
              ancestors[i].name as String,
              style: IosBrowse.subheadline(
                context,
              ).copyWith(color: scheme.primary),
            ),
          ),
        ),
      );
    }
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
