import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/file_type_detector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_tiles.dart';
import '../../widgets/tab_header.dart';
import '../drive/components/selection_mode_mixin.dart';
import '../drive/drive_controller.dart';
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
  final PhotoGridDensity _density = PhotoGridDensity();

  @override
  void dispose() {
    _density.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drive = ref.watch(driveControllerProvider);
    final files = drive.photoFiles('all');
    final allCount = files.length;

    return PopScope(
      canPop: !selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectMode) exitSelect();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (selectMode)
                PhotosSelectionBar(
                  selectedCount: selectedCount,
                  onCancel: exitSelect,
                  onShare: _onBulkShare,
                  onMove: _onBulkMove,
                  onDelete: _onBulkDelete,
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TabHeader(
                    title: 'Photos',
                    subtitle: allCount == 0
                        ? 'Your media library'
                        : '$allCount item${allCount == 1 ? '' : 's'}',
                  ),
                ),
                _PhotosToolbar(count: allCount, density: _density),
              ],
              Expanded(
                child: files.isEmpty
                    ? const EmptyState(
                        icon: Icons.photo_library_outlined,
                        title: 'No photos yet',
                        body: 'Photos and videos appear here after upload.',
                      )
                    : PhotosGridView(
                        files: files,
                        density: _density,
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

class _PhotosToolbar extends StatelessWidget {
  const _PhotosToolbar({required this.count, required this.density});
  final int count;
  final PhotoGridDensity density;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: density,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  count == 0 ? '' : '$count item${count == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Smaller tiles',
                onPressed: density.columns >= density.max
                    ? null
                    : density.zoomOut,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Larger tiles',
                onPressed: density.columns <= density.min
                    ? null
                    : density.zoomIn,
                icon: const Icon(Icons.grid_on_rounded, size: 18),
              ),
            ],
          ),
        );
      },
    );
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
    final starred = drive.starred();
    final totalItems = starred.files.length + starred.folders.length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TabHeader(
                  title: 'Starred',
                  subtitle: totalItems == 0
                      ? 'Quick access to favourites'
                      : '$totalItems item${totalItems == 1 ? '' : 's'}',
                ),
              ),
            ),
            if (starred.files.isEmpty && starred.folders.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.star_border,
                  title: 'Nothing starred',
                  body: 'Star files and folders for quick access.',
                ),
              ),
            if (starred.folders.isNotEmpty)
              SliverList.builder(
                itemCount: starred.folders.length,
                itemBuilder: (_, i) {
                  final folder = starred.folders[i];
                  return FileListTile(
                    name: folder.name,
                    subtitle:
                        '${folder.recursiveFileCount} files \u00b7 ${formatFileSize(folder.recursiveSize)}',
                    isFolder: true,
                    starred: true,
                    shared: folder.shared,
                    onTap: () => context.push('/folder/${folder.id}'),
                    onStar: () => ref
                        .read(driveControllerProvider)
                        .toggleStar(folder.id, folder: true),
                  );
                },
              ),
            if (starred.files.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 120),
                sliver: SliverList.builder(
                  itemCount: starred.files.length,
                  itemBuilder: (_, i) {
                    final file = starred.files[i];
                    return FileListTile(
                      name: file.name,
                      subtitle:
                          '${formatLabel(file)} \u00b7 ${formatFileSize(file.size)} \u00b7 ${formatDate(file.modifiedAt)}',
                      file: file,
                      starred: true,
                      onTap: () {
                        ref.read(driveControllerProvider).markAccessed(file.id);
                        context.push('/file/${file.id}');
                      },
                      onStar: () =>
                          ref.read(driveControllerProvider).toggleStar(file.id),
                    );
                  },
                ),
              ),
          ],
        ),
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
