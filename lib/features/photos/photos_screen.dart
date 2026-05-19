import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_tiles.dart';
import '../drive/components/drive_item_actions.dart';
import '../drive/components/selection_mode_mixin.dart';
import '../drive/drive_controller.dart';
import '../drive/view_preferences_controller.dart';
import '../search/search_controller.dart';
import '../share/my_shares_screen.dart';
import 'components/photo_context_menu.dart';
import 'components/photo_preview_overlay.dart';
import 'components/photos_selection_bar.dart';
import 'photos_actions.dart';
import 'photos_grid/photo_grid_density.dart';
import 'photos_grid/photos_grid_view.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen>
    with SelectionModeMixin<PhotosScreen> {
  @override
  Widget build(BuildContext context) {
    final drive = ref.watch(driveControllerProvider);
    final density = ref.watch(photoGridDensityProvider);
    final query = ref.watch(searchQueryProvider(SearchScope.photos)).query;
    final all = drive.photoFiles('all');
    final files = query.isEmpty
        ? all
        : all.where((f) => f.name.toLowerCase().contains(query)).toList();
    final allCount = files.length;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectMode) exitSelect();
      },
      child: Scaffold(
        body: Column(
          children: [
            if (selectMode)
              PhotosSelectionBar(
                selectedCount: selectedCount,
                onCancel: exitSelect,
                onShare: _onBulkShare,
                onMove: _onBulkMove,
                onDelete: _onBulkDelete,
              ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (!selectMode)
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
                              ? '$allCount match${allCount == 1 ? '' : 'es'}'
                              : (allCount == 0
                                    ? 'Your media library'
                                    : '$allCount item${allCount == 1 ? '' : 's'}'),
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  if (files.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: query.isEmpty
                            ? Icons.photo_library_outlined
                            : Icons.search_off,
                        title: query.isEmpty
                            ? 'No photos yet'
                            : 'No matching photos',
                        body: query.isEmpty
                            ? 'Photos and videos appear here after upload.'
                            : 'Try a different file name.',
                      ),
                    )
                  else
                    SliverFillRemaining(
                      child: PhotosGridView(
                        files: files,
                        density: density,
                        loadingMore: drive.state.loadingMoreMedia,
                        selectMode: selectMode,
                        selectedIds: selectedFileIds,
                        onTileTap: _onTileTap,
                        onTileLongPress: _onTileLongPress,
                        onTilePanSelect: _onTilePanSelect,
                        onLoadMore: () =>
                            ref.read(driveControllerProvider).loadMoreMedia(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTileTap(String fileId) {
    if (selectMode) {
      toggleFileSelection(fileId);
      return;
    }
    context.push('/photos/view/$fileId?filter=all');
  }

  void _onTileLongPress(String fileId, GlobalKey key) {
    if (selectMode) {
      toggleFileSelection(fileId);
      return;
    }
    final anchor = resolveTileAnchor(key, context);
    if (anchor == null) return;
    final drive = ref.read(driveControllerProvider);
    final file = drive.file(fileId);
    if (file == null) return;
    HapticFeedback.mediumImpact();
    showPhotoPreviewOverlay(
      context: context,
      sourceRect: anchor,
      file: file,
      onShare: () => PhotosActions.share(context, ref, fileIds: {fileId}),
      onMove: () => PhotosActions.move(context, ref, fileIds: {fileId}),
      onSelect: () => enterSelect(fileId: fileId),
    );
  }

  void _onTilePanSelect(String fileId) {
    if (!selectedFileIds.contains(fileId)) {
      setState(() => selectedFileIds.add(fileId));
    }
  }

  Future<void> _onBulkShare() async {
    final ids = Set<String>.from(selectedFileIds);
    await PhotosActions.share(context, ref, fileIds: ids);
  }

  Future<void> _onBulkMove() async {
    final ids = Set<String>.from(selectedFileIds);
    await PhotosActions.move(context, ref, fileIds: ids);
    if (mounted) exitSelect();
  }

  Future<void> _onBulkDelete() async {
    final ids = Set<String>.from(selectedFileIds);
    final ok = await PhotosActions.delete(context, ref, fileIds: ids);
    if (mounted && ok) exitSelect();
  }
}

// ---------------------------------------------------------------------------
// Starred
// ---------------------------------------------------------------------------

class StarredScreen extends ConsumerWidget {
  const StarredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveControllerProvider);
    final prefs = ref.watch(viewPreferencesProvider);
    final query = ref.watch(searchQueryProvider(SearchScope.starred)).query;
    final raw = drive.starred();
    var starredFiles = query.isEmpty
        ? raw.files
        : raw.files.where((f) => f.name.toLowerCase().contains(query)).toList();
    var starredFolders = query.isEmpty
        ? raw.folders
        : raw.folders
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

    return Scaffold(
      body: CustomScrollView(
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
          if (starredFiles.isEmpty && starredFolders.isEmpty)
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
                  subtitle:
                      '${folder.recursiveFileCount} files · ${formatFileSize(folder.recursiveSize)}',
                  isFolder: true,
                  starred: true,
                  shared: folder.shared,
                  onTap: () => context.push('/folder/${folder.id}'),
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
                            childAspectRatio: .82,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: starredFiles.length,
                      itemBuilder: (_, i) {
                        final file = starredFiles[i];
                        return FileCardTile(
                          key: ValueKey(file.id),
                          file: file,
                          onTap: () {
                            ref
                                .read(driveControllerProvider)
                                .markAccessed(file.id);
                            context.push('/file/${file.id}');
                          },
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
                          onTap: () {
                            ref
                                .read(driveControllerProvider)
                                .markAccessed(file.id);
                            context.push('/file/${file.id}');
                          },
                          onStar: () => ref
                              .read(driveControllerProvider)
                              .toggleStar(file.id),
                          onMore: () =>
                              DriveItemActions.openFile(context, ref, file),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class SharedScreen extends StatelessWidget {
  const SharedScreen({super.key});

  @override
  Widget build(BuildContext context) => const MySharesScreen();
}
