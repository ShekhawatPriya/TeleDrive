import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/safe_navigation.dart';
import '../../core/utils/file_type_detector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_card_tile.dart';
import '../../widgets/file_list_tile.dart';
import '../../widgets/skeletons.dart';
import 'components/drive_item_actions.dart';
import 'components/drive_list_slivers.dart';
import 'drive_controller.dart';
import 'view_preferences_controller.dart';
import '../search/search_controller.dart';

class StarredScreen extends ConsumerStatefulWidget {
  const StarredScreen({super.key});

  @override
  ConsumerState<StarredScreen> createState() => _StarredScreenState();
}

class _StarredScreenState extends ConsumerState<StarredScreen> {
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
    final theme = Theme.of(context);
    final grid = prefs.layout == LayoutMode.grid;
    final loaded = snapshot.loaded;
    final loading = snapshot.loading;
    final hasMore = snapshot.hasMore;
    final loadingMore = snapshot.loadingMore;

    return Scaffold(
      body: RefreshIndicator(
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  query.isNotEmpty
                      ? '$totalItems match${totalItems == 1 ? '' : 'es'}'
                      : (totalItems == 0
                            ? 'Quick access to favourites'
                            : '$totalItems item${totalItems == 1 ? '' : 's'}'),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
            if (!loaded && loading)
              const SliverFillRemaining(child: SkeletonList()),
            if (loaded && starredFiles.isEmpty && starredFolders.isEmpty)
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
                  return FileListTile(
                    name: folder.name,
                    // TODO(direct-counts): rename when API exposes
                    // directFileCount/directSizeBytes/childFolderCount.
                    subtitle:
                        '${folder.recursiveFileCount} files · ${formatFileSize(folder.recursiveSize)}',
                    isFolder: true,
                    starred: true,
                    shared: folder.shared,
                    onTap: () => context.safePush('/folder/${folder.id}'),
                    onStar: () => ref
                        .read(driveControllerProvider)
                        .toggleStar(folder.id, folder: true),
                    onMore: () =>
                        DriveItemActions.openFolder(context, ref, folder),
                  );
                },
              ),
            if (starredFiles.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 120),
                sliver: grid
                    ? SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: .72,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: starredFiles.length,
                        itemBuilder: (_, i) {
                          final file = starredFiles[i];
                          return FileCardTile(
                            key: ValueKey(file.localId ?? file.id),
                            file: file,
                            onTap: () => openDriveFile(context, ref, file),
                            onMore: () =>
                                DriveItemActions.openFile(context, ref, file),
                          );
                        },
                      )
                    : SliverList.builder(
                        itemCount: starredFiles.length,
                        itemBuilder: (_, i) {
                          final file = starredFiles[i];
                          return FileListTile(
                            name: file.name,
                            subtitle:
                                '${formatLabel(file)} · ${formatFileSize(file.size)} · ${formatDate(file.modifiedAt)}',
                            file: file,
                            starred: true,
                            onTap: () => openDriveFile(context, ref, file),
                            onStar: () => ref
                                .read(driveControllerProvider)
                                .toggleStar(file.id),
                            onMore: () =>
                                DriveItemActions.openFile(context, ref, file),
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
    );
  }
}
