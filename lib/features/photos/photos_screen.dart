import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/safe_navigation.dart';
import '../../widgets/empty_state.dart';
import '../drive/components/drive_item_actions.dart';
import '../drive/components/selection_mode_mixin.dart';
import '../drive/components/share_helpers.dart';
import '../drive/drive_controller.dart';
import '../drive/drive_tab_commands.dart';
import '../search/search_controller.dart';
import 'components/photo_context_menu.dart';
import 'components/photo_preview_overlay.dart';
import 'components/photos_selection_bar.dart';
import 'photos_grid/photo_grid_density.dart';
import 'photos_filter.dart';
import 'photos_grid/photos_grid_view.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen>
    with SelectionModeMixin<PhotosScreen> {
  PhotosFilter _filter = PhotosFilter.all;
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
    final all = drive.photoFiles('all').where(_filter.accepts).toList();
    final files = query.isEmpty
        ? all
        : all.where((f) => f.name.toLowerCase().contains(query)).toList();
    final allCount = files.length;
    final theme = Theme.of(context);

    final modalRoute = ModalRoute.of(context);
    final isCurrent = modalRoute?.isCurrent ?? true;

    return PopScope(
      canPop: !isCurrent || !selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isCurrent && selectMode) {
          exitSelect();
        }
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
            if (!selectMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (theme.platform == TargetPlatform.iOS &&
                        MediaQuery.textScalerOf(context).scale(14) <= 22)
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<PhotosFilter>(
                          groupValue: _filter,
                          backgroundColor: theme.colorScheme.surfaceContainer,
                          thumbColor: theme.colorScheme.surfaceContainerLow,
                          children: {
                            for (final filter in PhotosFilter.values)
                              filter: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                child: Text(
                                  filter == PhotosFilter.all
                                      ? 'All media'
                                      : filter.label,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                          },
                          onValueChanged: (filter) {
                            if (filter != null)
                              setState(() => _filter = filter);
                          },
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final filter in PhotosFilter.values)
                            ChoiceChip(
                              label: Text(
                                filter == PhotosFilter.all
                                    ? 'All media'
                                    : filter.label,
                              ),
                              selected: _filter == filter,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      query.isNotEmpty
                          ? '$allCount matches in loaded photos'
                          : '$allCount items in your loaded library',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => drive.refresh(force: true),
                child: files.isNotEmpty
                    ? PhotosGridView(
                        files: files,
                        showCover: query.isEmpty,
                        density: density,
                        loadingMore: drive.state.loadingMoreMedia,
                        selectMode: selectMode,
                        selectedIds: selectedFileIds,
                        onTileTap: _onTileTap,
                        onTileLongPress: _onTileLongPress,
                        onTileSelect: (id) => enterSelect(fileId: id),
                        onTilePanSelect: _onTilePanSelect,
                        onLoadMore: () =>
                            ref.read(driveControllerProvider).loadMoreMedia(),
                      )
                    : CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: drive.state.loading
                                ? const Center(
                                    child: CircularProgressIndicator.adaptive(),
                                  )
                                : drive.state.error != null
                                ? EmptyState(
                                    icon: Icons.cloud_off_outlined,
                                    title: 'Could not load your photos',
                                    body: drive.state.error!,
                                    action: TextButton(
                                      onPressed: () =>
                                          drive.refresh(force: true),
                                      child: const Text('Try again'),
                                    ),
                                  )
                                : EmptyState(
                                    icon: query.isEmpty
                                        ? Icons.photo_library_outlined
                                        : Icons.search_off,
                                    title: query.isEmpty
                                        ? 'No photos yet'
                                        : 'No matching photos',
                                    body: query.isEmpty
                                        ? 'Photos and videos appear here after upload.'
                                        : 'Try a different name. Search covers photos loaded on this device.',
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
            if (selectMode && theme.platform == TargetPlatform.iOS)
              PhotosSelectionBar(
                actionsOnly: true,
                selectedCount: selectedCount,
                onCancel: exitSelect,
                onShare: () => bulkShare(context),
                onMove: () => bulkMove(context),
                onDelete: () => bulkDelete(context),
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
    context.safePush('/photos/view/$fileId?filter=${_filter.queryValue}');
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
      onShare: () {
        if (file.shared) {
          revokeFileShares(context, ref, file);
        } else {
          DriveBulkActions.share(
            context,
            ref,
            fileIds: {fileId},
            folderIds: const {},
          );
        }
      },
      onMove: () => DriveBulkActions.move(
        context,
        ref,
        fileIds: {fileId},
        folderIds: const {},
      ),
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
