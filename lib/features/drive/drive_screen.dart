import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/safe_navigation.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/teledrive_app_bar.dart';
import '../search/search_controller.dart';
import '../search/drive_search_controller.dart';
import 'components/drive_header_widgets.dart';
import 'components/drive_item_actions.dart';
import 'components/drive_list_slivers.dart';
import 'components/drive_selection_bar.dart';
import 'components/selection_mode_mixin.dart';
import 'drive_controller.dart';
import 'drive_tab_commands.dart';
import 'view_preferences_controller.dart';
import 'virtual_sections.dart';

class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key});

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen>
    with SelectionModeMixin<DriveScreen> {
  int _handledSelectRequests = 0;

  List<DriveFile>? _sortedFiles;
  ({List<DriveFile> source, SortField sort, bool ascending, String query})?
  _sortedFilesKey;
  List<DriveFolder>? _sortedFolders;
  ({List<DriveFolder> source, bool ascending, String query})? _sortedFoldersKey;

  List<DriveFile> _memoSortedFiles({
    required List<DriveFile> source,
    required SortField sort,
    required bool ascending,
    required String query,
  }) {
    final key = (
      source: source,
      sort: sort,
      ascending: ascending,
      query: query,
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
    required String query,
  }) {
    final key = (source: source, ascending: ascending, query: query);
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
      ref.read(driveControllerProvider).setActiveFolderId(null);
    });
  }

  @override
  void dispose() {
    try {
      ref.read(selectionModeStateProvider).setDriveSelectMode(false);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commands = ref.watch(driveTabCommandsProvider);
    if (commands.selectRequests != _handledSelectRequests) {
      _handledSelectRequests = commands.selectRequests;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !selectMode) setState(() => selectMode = true);
      });
    }

    final selectState = ref.read(selectionModeStateProvider);
    if (selectState.driveSelectMode != selectMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectionModeStateProvider).setDriveSelectMode(selectMode);
        }
      });
    }

    final search = ref.watch(driveSearchProvider);
    final prefs = ref.watch(viewPreferencesProvider);
    final query = ref.watch(searchQueryProvider(SearchScope.drive)).query;
    final snapshot = ref.watch(
      driveControllerProvider.select((c) => c.folderViewSnapshot(null)),
    );
    final recentsSnapshot = ref.watch(
      driveControllerProvider.select((c) => c.recentsSnapshot()),
    );

    var folders = snapshot.folders;
    var files = snapshot.files;
    if (query.isNotEmpty) {
      // Server-backed file search across the entire drive (G6).
      files = search.files;
      // Folder search filters cumulative metadata only — see banner below.
      folders = ref
          .read(driveControllerProvider)
          .folders
          .where((f) => f.name.toLowerCase().contains(query))
          .toList();
    }
    folders = hideVirtualSectionFolders(folders);
    folders = _memoSortedFolders(
      source: folders,
      ascending: prefs.ascending,
      query: query,
    );
    files = _memoSortedFiles(
      source: files,
      sort: prefs.sort,
      ascending: prefs.ascending,
      query: query,
    );
    final recent = recentsSnapshot.files;
    final loaded = snapshot.loaded;
    final loading = snapshot.loading;
    final hasMore = snapshot.hasMore;
    final loadingMore = snapshot.loadingMore;
    final error = snapshot.error;
    final grid = prefs.layout == LayoutMode.grid;

    if (selectMode) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              DriveSelectionBar(
                selectedCount: selectedCount,
                onSelectAll: () => selectAllItems(files, folders),
                onClear: clearSelection,
                onCancel: exitSelect,
                onShare: () => bulkShare(context),
                onStar: bulkStar,
                onMove: () => bulkMove(context),
                onDelete: () => bulkDelete(context),
              ),
              if (Theme.of(context).platform == TargetPlatform.iOS)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: DriveSearchField(
                    scope: SearchScope.drive,
                    selectionMode: true,
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: query.isNotEmpty
                      ? search.refresh
                      : ref.read(driveControllerProvider).refresh,
                  child: CustomScrollView(
                    slivers: [
                      if (folders.isNotEmpty)
                        const DriveSectionHeader('Folders', bottomPadding: 0),
                      DriveFolderSliver(
                        folders: folders,
                        selectMode: true,
                        selectedFolderIds: selectedFolderIds,
                        onFolderTap: _onFolderTap,
                        onFolderLongPress: (id) => enterSelect(folderId: id),
                        onFolderMore: (folder) =>
                            DriveItemActions.openFolder(context, ref, folder),
                      ),
                      if (files.isNotEmpty)
                        const DriveSectionHeader('Files', bottomPadding: 0),
                      DriveFilesSliver(
                        files: files,
                        grid: grid,
                        selectMode: true,
                        selectedFileIds: selectedFileIds,
                        onFileTap: _onFileTap,
                        onFileLongPress: (id) => enterSelect(fileId: id),
                        onFileMore: (file) =>
                            DriveItemActions.openFile(context, ref, file),
                      ),
                    ],
                  ),
                ),
              ),
              if (Theme.of(context).platform == TargetPlatform.iOS)
                DriveSelectionBar(
                  actionsOnly: true,
                  selectedCount: selectedCount,
                  onSelectAll: () => selectAllItems(files, folders),
                  onClear: clearSelection,
                  onCancel: exitSelect,
                  onShare: () => bulkShare(context),
                  onStar: bulkStar,
                  onMove: () => bulkMove(context),
                  onDelete: () => bulkDelete(context),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: query.isNotEmpty
            ? search.refresh
            : ref.read(driveControllerProvider).refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (query.isNotEmpty &&
                notification.metrics.extentAfter < 200 &&
                search.error == null) {
              search.loadMore();
            }
            if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200 &&
                hasMore &&
                !loadingMore &&
                query.isEmpty) {
              ref.read(driveControllerProvider).loadMoreFolder(null);
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (!loaded && loading)
                const SliverFillRemaining(child: SkeletonList()),
              if (error != null) _ErrorBanner(error),
              if (search.error != null && query.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(search.error!),
                        TextButton(
                          onPressed: search.loadMore,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (query.isEmpty) ...[
                const DriveSectionHeader(
                  'Your spaces',
                  topPadding: AppSpacing.sm,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, 0),
                    child: DriveQuickActions(
                      onTrashTap: () => context.safePush('/settings/trash'),
                      onArchiveTap: () => context.safePush('/settings/archive'),
                      onLockedTap: () => context.safePush('/settings/locked'),
                    ),
                  ),
                ),
              ],
              if (recent.isNotEmpty && query.isEmpty) ...[
                const DriveSectionHeader('Recent files'),
                SliverToBoxAdapter(
                  child: DriveRecentsStrip(
                    files: recent,
                    onSelect: (f) => enterSelect(fileId: f.id),
                    onFileTap: (f) => openDriveFile(context, ref, f),
                    onMore: (f) => DriveItemActions.openFile(context, ref, f),
                  ),
                ),
              ],
              if ((query.isEmpty ? loaded : search.loaded) &&
                  !search.loading &&
                  folders.isEmpty &&
                  files.isEmpty)
                SliverFillRemaining(
                  child: EmptyState(
                    icon: query.isEmpty ? Icons.folder_open : Icons.search_off,
                    title: query.isEmpty ? 'Your Drive is empty' : 'No results',
                    body: query.isEmpty
                        ? 'Upload files or create a folder to get started.'
                        : 'Try a different file or folder name.',
                  ),
                ),
              if (folders.isNotEmpty)
                const DriveSectionHeader('Folders', bottomPadding: 0),
              if (folders.isNotEmpty && query.isNotEmpty)
                const SliverToBoxAdapter(child: _PartialFoldersBanner()),
              DriveFolderSliver(
                folders: folders,
                selectMode: false,
                selectedFolderIds: selectedFolderIds,
                onFolderTap: _onFolderTap,
                onFolderLongPress: (id) => enterSelect(folderId: id),
                onFolderMore: (folder) =>
                    DriveItemActions.openFolder(context, ref, folder),
              ),
              if (files.isNotEmpty)
                const DriveSectionHeader('Files', bottomPadding: 0),
              DriveFilesSliver(
                files: files,
                grid: grid,
                selectMode: false,
                selectedFileIds: selectedFileIds,
                onFileTap: _onFileTap,
                onFileLongPress: (id) => enterSelect(fileId: id),
                onFileMore: (file) =>
                    DriveItemActions.openFile(context, ref, file),
              ),
              if (loadingMore && query.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (search.loading && query.isNotEmpty)
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: AppRadii.mdR,
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Partial-folder-search banner (G6). Folder search filters cumulative
/// metadata only — folders the user hasn't navigated into are not in the
/// local index. The banner names this limitation explicitly.
class _PartialFoldersBanner extends StatelessWidget {
  const _PartialFoldersBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        'Folders matched in your loaded sections — open a folder to discover more.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
