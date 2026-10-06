import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/safe_navigation.dart';
import '../../core/utils/file_type_detector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/adaptive_surface.dart';
import '../../widgets/file_card_tile.dart';
import '../../widgets/file_list_tile.dart';
import '../../widgets/skeletons.dart';
import 'components/drive_item_actions.dart';
import 'components/drive_item_context_menu.dart';
import 'components/selection_mode_mixin.dart';
import 'components/drive_selection_bar.dart';
import 'drive_tab_commands.dart';
import 'components/drive_list_slivers.dart';
import 'drive_controller.dart';
import 'view_preferences_controller.dart';
import '../search/search_controller.dart';

class StarredScreen extends ConsumerStatefulWidget {
  const StarredScreen({super.key});

  @override
  ConsumerState<StarredScreen> createState() => _StarredScreenState();
}

class _StarredScreenState extends ConsumerState<StarredScreen>
    with SelectionModeMixin<StarredScreen> {
  int _handledSelectRequests = 0;

  @override
  void dispose() {
    try {
      ref.read(selectionModeStateProvider).setStarredSelectMode(false);
    } catch (_) {}
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(driveControllerProvider).ensureStarredLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(starredTabCommandsProvider).selectRequests;
    if (requests != _handledSelectRequests) {
      _handledSelectRequests = requests;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) enterSelect();
      });
    }
    if (ref.read(selectionModeStateProvider).starredSelectMode != selectMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ref.read(selectionModeStateProvider).setStarredSelectMode(selectMode);
      });
    }
    final snapshot = ref.watch(
      driveControllerProvider.select((c) => c.starredSnapshot()),
    );
    final prefs = ref.watch(viewPreferencesProvider);
    final query = ref.watch(searchQueryProvider(SearchScope.starred)).query;
    var starredFiles = query.isEmpty
        ? snapshot.files
        : snapshot.files
              .where((f) => f.name.toLowerCase().contains(query))
              .toList();
    var starredFolders = query.isEmpty
        ? snapshot.folders
        : snapshot.folders
              .where((f) => f.name.toLowerCase().contains(query))
              .toList();
    starredFolders = sortDriveFolders(
      starredFolders,
      ascending: prefs.ascending,
    );
    starredFiles = sortDriveFiles(
      starredFiles,
      sort: prefs.sort,
      ascending: prefs.ascending,
    );
    final totalItems = starredFiles.length + starredFolders.length;
    final grid =
        !selectMode &&
        prefs.layout == LayoutMode.grid &&
        MediaQuery.textScalerOf(context).scale(14) <= 22;
    final loaded = snapshot.loaded;
    final loading = snapshot.loading;
    final hasMore = snapshot.hasMore;
    final loadingMore = snapshot.loadingMore;

    Widget selection({bool actionsOnly = false}) => DriveSelectionBar(
      actionsOnly: actionsOnly,
      selectedCount: selectedCount,
      onSelectAll: () => selectAllItems(starredFiles, starredFolders),
      onClear: clearSelection,
      onCancel: exitSelect,
      onShare: () => bulkShare(context),
      onStar: bulkStar,
      onMove: () => bulkMove(context),
      onDelete: () => bulkDelete(context),
    );
    return Scaffold(
      body: Column(
        children: [
          if (selectMode) selection(),
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => ref
                      .read(driveControllerProvider)
                      .ensureStarredLoaded(force: true),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      // Only paginate the unfiltered server-backed list. A typed-search
                      // is filtering the loaded cache locally; loading more pages would
                      // not change those results.
                      if (query.isEmpty &&
                          hasMore &&
                          !loadingMore &&
                          n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                        ref.read(driveControllerProvider).loadMoreStarred();
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: CollectionIntro(
                            title: query.isEmpty
                                ? 'The important things.'
                                : 'Search results',
                            description: query.isEmpty
                                ? 'Your handpicked files and folders, together in one place.'
                                : 'Matches from the starred items loaded on this device.',
                            icon: Icons.star_rounded,
                            detail: loaded
                                ? '$totalItems${hasMore ? '+' : ''} ${query.isEmpty ? 'saved items' : 'matches'}'
                                : 'Your collection',
                          ),
                        ),
                        if (!loaded && loading)
                          const SliverFillRemaining(child: SkeletonList()),
                        if (snapshot.error != null &&
                            starredFiles.isEmpty &&
                            starredFolders.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.cloud_off_outlined,
                              title: 'Could not load starred items',
                              body: snapshot.error!,
                              action: TextButton(
                                onPressed: () => ref
                                    .read(driveControllerProvider)
                                    .ensureStarredLoaded(force: true),
                                child: const Text('Try again'),
                              ),
                            ),
                          ),
                        if (snapshot.error == null &&
                            loaded &&
                            starredFiles.isEmpty &&
                            starredFolders.isEmpty)
                          SliverFillRemaining(
                            child: EmptyState(
                              icon: query.isEmpty
                                  ? Icons.star_border_rounded
                                  : Icons.search_off,
                              title: query.isEmpty
                                  ? 'Nothing starred'
                                  : 'No matching starred items',
                              body: query.isEmpty
                                  ? 'Star files and folders for quick access.'
                                  : 'Try a different name.',
                            ),
                          ),
                        if (starredFolders.isNotEmpty)
                          SliverList.builder(
                            itemCount: starredFolders.length,
                            itemBuilder: (_, i) {
                              final folder = starredFolders[i];
                              return DriveItemContextMenu(
                                folder: folder,
                                enabled: !selectMode,
                                trailingClearance: 48,
                                onOpen: () =>
                                    context.safePush('/folder/${folder.id}'),
                                onSelect: () =>
                                    enterSelect(folderId: folder.id),
                                child: FileListTile(
                                  selected: selectMode
                                      ? selectedFolderIds.contains(folder.id)
                                      : null,
                                  name: folder.name,
                                  // TODO(direct-counts): rename when API exposes
                                  // directFileCount/directSizeBytes/childFolderCount.
                                  subtitle:
                                      '${folder.recursiveFileCount} files · ${formatFileSize(folder.recursiveSize)}',
                                  isFolder: true,
                                  starred: true,
                                  shared: folder.shared,
                                  onLongPress:
                                      Theme.of(context).platform ==
                                              TargetPlatform.iOS &&
                                          !selectMode
                                      ? null
                                      : () => enterSelect(folderId: folder.id),
                                  onTap: () => selectMode
                                      ? toggleFolderSelection(folder.id)
                                      : context.safePush(
                                          '/folder/${folder.id}',
                                        ),
                                  onStar: () => ref
                                      .read(driveControllerProvider)
                                      .toggleStar(folder.id, folder: true),
                                  onMore: () => DriveItemActions.openFolder(
                                    context,
                                    ref,
                                    folder,
                                  ),
                                ),
                              );
                            },
                          ),
                        if (starredFiles.isNotEmpty)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              grid ? 20 : 0,
                              8,
                              grid ? 20 : 0,
                              160,
                            ),
                            sliver: grid
                                ? SliverGrid.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 260,
                                          childAspectRatio: .72,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                    itemCount: starredFiles.length,
                                    itemBuilder: (_, i) {
                                      final file = starredFiles[i];
                                      return DriveItemContextMenu(
                                        file: file,
                                        enabled: !selectMode,
                                        trailingClearance: 48,
                                        onOpen: () =>
                                            openDriveFile(context, ref, file),
                                        onSelect: () =>
                                            enterSelect(fileId: file.id),
                                        child: FileCardTile(
                                          selected: selectMode
                                              ? selectedFileIds.contains(
                                                  file.id,
                                                )
                                              : null,
                                          key: ValueKey(
                                            file.localId ?? file.id,
                                          ),
                                          file: file,
                                          onLongPress:
                                              Theme.of(context).platform ==
                                                      TargetPlatform.iOS &&
                                                  !selectMode
                                              ? null
                                              : () => enterSelect(
                                                  fileId: file.id,
                                                ),
                                          onTap: () => selectMode
                                              ? toggleFileSelection(file.id)
                                              : openDriveFile(
                                                  context,
                                                  ref,
                                                  file,
                                                ),
                                          onMore: () =>
                                              DriveItemActions.openFile(
                                                context,
                                                ref,
                                                file,
                                              ),
                                        ),
                                      );
                                    },
                                  )
                                : SliverList.builder(
                                    itemCount: starredFiles.length,
                                    itemBuilder: (_, i) {
                                      final file = starredFiles[i];
                                      return DriveItemContextMenu(
                                        file: file,
                                        enabled: !selectMode,
                                        trailingClearance: 48,
                                        onOpen: () =>
                                            openDriveFile(context, ref, file),
                                        onSelect: () =>
                                            enterSelect(fileId: file.id),
                                        child: FileListTile(
                                          selected: selectMode
                                              ? selectedFileIds.contains(
                                                  file.id,
                                                )
                                              : null,
                                          name: file.name,
                                          subtitle:
                                              '${formatLabel(file)} · ${formatFileSize(file.size)} · ${formatDate(file.modifiedAt)}',
                                          file: file,
                                          starred: true,
                                          onLongPress:
                                              Theme.of(context).platform ==
                                                      TargetPlatform.iOS &&
                                                  !selectMode
                                              ? null
                                              : () => enterSelect(
                                                  fileId: file.id,
                                                ),
                                          onTap: () => selectMode
                                              ? toggleFileSelection(file.id)
                                              : openDriveFile(
                                                  context,
                                                  ref,
                                                  file,
                                                ),
                                          onStar: () => ref
                                              .read(driveControllerProvider)
                                              .toggleStar(file.id),
                                          onMore: () =>
                                              DriveItemActions.openFile(
                                                context,
                                                ref,
                                                file,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
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
                    child: selection(actionsOnly: true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
