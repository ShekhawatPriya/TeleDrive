import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/safe_navigation.dart';
import '../../widgets/empty_state.dart';
import '../drive/components/drive_item_actions.dart';
import '../drive/components/selection_mode_mixin.dart';
import '../drive/drive_controller.dart';
import '../drive/drive_tab_commands.dart';
import '../search/search_controller.dart';
import 'components/photo_context_menu.dart';
import 'components/photo_preview_overlay.dart';
import 'components/photos_selection_bar.dart';
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
    final selectState = ref.read(selectionModeStateProvider);
    if (selectState.photosSelectMode != selectMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectionModeStateProvider).setPhotosSelectMode(selectMode);
        }
      });
    }

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
                onShare: () => bulkShare(context),
                onMove: () => bulkMove(context),
                onDelete: () => bulkDelete(context),
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
    context.safePush('/photos/view/$fileId?filter=all');
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
      onShare: () => DriveBulkActions.share(context, ref, fileIds: {fileId}, folderIds: const {}),
      onMove: () => DriveBulkActions.move(context, ref, fileIds: {fileId}, folderIds: const {}),
      onSelect: () => enterSelect(fileId: fileId),
    );
  }

  void _onTilePanSelect(String fileId) {
    if (!selectedFileIds.contains(fileId)) {
      setState(() => selectedFileIds.add(fileId));
    }
  }

  @override
  void dispose() {
    try {
      ref.read(selectionModeStateProvider).setPhotosSelectMode(false);
    } catch (_) {}
    super.dispose();
  }
}

