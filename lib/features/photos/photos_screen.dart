import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../../widgets/search_keyboard.dart';
import '../../widgets/ios/ios_browse.dart';
import '../../widgets/ios/ios_tab_header.dart';
import '../../widgets/ios_more_menu.dart';
import 'photos_viewer/photo_viewer_session.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/teledrive_app_bar.dart';
import '../drive/components/drive_item_actions.dart';
import '../drive/components/selection_mode_mixin.dart';
import '../drive/drive_controller.dart';
import '../drive/drive_tab_commands.dart';
import '../search/search_controller.dart';
import 'components/photo_context_menu.dart';
import 'components/photo_preview_overlay.dart';
import 'components/photos_selection_bar.dart';
import 'components/photos_library_controls.dart';
import 'components/photos_menu_builder.dart';
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
  bool _viewerOpen = false;
  final _gridKey = GlobalKey<PhotosGridViewState>();
  Set<String> _rangeBase = {};
  bool _rangeSelect = true;

  int _handledSelectRequests = 0;

  List<IosMenuSection> _menus(BuildContext context) => buildPhotosMenuSections(
    context,
    density: ref.read(photoGridDensityProvider),
    onSelect: () => enterSelect(),
  );

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(photosTabCommandsProvider).selectRequests;
    if (requests != _handledSelectRequests) {
      _handledSelectRequests = requests;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) enterSelect();
      });
    }
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
    final ios = theme.platform == TargetPlatform.iOS;

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
        // Same canvas as the other iOS tabs, so the header and library read
        // as one surface.
        backgroundColor: ios ? IosBrowse.canvas(context) : null,
        body: Column(
          children: [
            if (selectMode)
              PhotosSelectionBar(
                selectedCount: selectedCount,
                onSelectAll: () => selectAllItems(files),
                onClear: clearSelection,
                onCancel: exitSelect,
                onShare: () => bulkShare(context),
                onMove: () => bulkMove(context),
                onDelete: () => bulkDelete(context),
              ),
            if (selectMode && theme.platform == TargetPlatform.iOS)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: DriveSearchField(
                  scope: SearchScope.photos,
                  selectionMode: true,
                ),
              ),
            if (!selectMode && !ios)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: PhotosLibraryControls(
                  filter: _filter,
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                ),
              ),
            Expanded(
              child: _refreshHost(
                ios: ios,
                onRefresh: () => drive.refresh(force: true),
                child: TickerMode(
                  enabled: !_viewerOpen,
                  child: PhotosGridView(
                    key: _gridKey,
                    files: files,
                    density: density,
                    loadingMore: drive.state.loadingMoreMedia,
                    selectMode: selectMode,
                    selectedIds: selectedFileIds,
                    onTileTap: _onTileTap,
                    onTileLongPress: _onTileLongPress,
                    onTileSelect: (id) => enterSelect(fileId: id),
                    onTilePanSelect: _onTilePanSelect,
                    onSelectionStart: () =>
                        _rangeBase = Set.of(selectedFileIds),
                    onSelectionRange: (start, end) {
                      final ids = files.map((f) => f.id).toList();
                      final a = ids.indexOf(start), b = ids.indexOf(end);
                      if (a < 0 || b < 0) return;
                      _rangeSelect = !_rangeBase.contains(start);
                      final selectable = files
                          .where((file) => !file.isOptimistic)
                          .map((file) => file.id)
                          .toSet();
                      final range = ids
                          .sublist(a < b ? a : b, (a > b ? a : b) + 1)
                          .where(selectable.contains);
                      setState(() {
                        selectedFileIds.clear();
                        selectedFileIds.addAll(_rangeBase);
                        if (_rangeSelect) {
                          selectedFileIds.addAll(range);
                        } else {
                          selectedFileIds.removeAll(range);
                        }
                      });
                    },
                    onRefresh: () => drive.refresh(force: true),
                    onLoadMore: () {
                      if (drive.state.mediaError == null) drive.loadMoreMedia();
                    },
                    leadingSlivers: [
                      if (ios && !selectMode) ...[
                        IosLargeTitleHeader(
                          title: 'Photos',
                          trailing: IosHeaderActions(
                            menuSections: _menus,
                            tooltip: 'Photos options',
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            child: PhotosLibraryControls(
                              filter: _filter,
                              onFilterChanged: (filter) =>
                                  setState(() => _filter = filter),
                            ),
                          ),
                        ),
                      ],
                      if (files.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: drive.state.loading
                              ? const Center(
                                  child: CircularProgressIndicator.adaptive(),
                                )
                              : EmptyState(
                                  icon: drive.state.error != null
                                      ? Icons.cloud_off_outlined
                                      : Icons.photo_library_outlined,
                                  title: drive.state.error != null
                                      ? 'Could not load your photos'
                                      : query.isNotEmpty
                                      ? 'No matching photos'
                                      : _filter == PhotosFilter.videos
                                      ? 'No videos yet'
                                      : 'No photos yet',
                                  body:
                                      drive.state.error ??
                                      (query.isNotEmpty
                                          ? 'Try a different name. Search covers media loaded on this device.'
                                          : 'Photos and videos appear here after upload.'),
                                  action: drive.state.error == null
                                      ? null
                                      : TextButton(
                                          onPressed: () =>
                                              drive.refresh(force: true),
                                          child: const Text('Try again'),
                                        ),
                                ),
                        ),
                    ],
                    trailingSlivers: [
                      if (drive.state.mediaError != null)
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Text(drive.state.mediaError!),
                              TextButton(
                                onPressed: drive.loadMoreMedia,
                                child: const Text('Retry loading more'),
                              ),
                            ],
                          ),
                        ),
                      if (files.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                            child: Text(
                              query.isEmpty
                                  ? '$allCount items in your loaded library'
                                  : '$allCount matches in loaded photos',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                      if (files.isNotEmpty && drive.state.error != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(drive.state.error!),
                                TextButton(
                                  onPressed: () => drive.refresh(force: true),
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (selectMode && theme.platform == TargetPlatform.iOS)
              PhotosSelectionBar(
                actionsOnly: true,
                selectedCount: selectedCount,
                onSelectAll: () => selectAllItems(files),
                onClear: clearSelection,
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

  Widget _refreshHost({
    required bool ios,
    required Future<void> Function() onRefresh,
    required Widget child,
  }) => ios ? child : RefreshIndicator(onRefresh: onRefresh, child: child);

  void _onTileTap(String fileId) {
    if (selectMode) {
      toggleFileSelection(fileId);
      return;
    }
    final query = ref.read(searchQueryProvider(SearchScope.photos)).query;
    final session = PhotoViewerSession(
      filter: _filter,
      query: query,
      currentId: fileId,
      generation: ref.read(driveControllerProvider).accountGeneration,
      sourceRect: (id) => _gridKey.currentState?.sourceRect(id),
      revealSource: (id) async => _gridKey.currentState?.revealFile(id),
    );
    final location = Uri(
      path: '/photos/view/$fileId',
      queryParameters: {
        'filter': _filter.queryValue,
        if (query.isNotEmpty) 'q': query,
      },
    ).toString();
    if (_viewerOpen) return;
    dismissSearchKeyboard();
    setState(() => _viewerOpen = true);
    context.push<void>(location, extra: session).whenComplete(() {
      if (mounted) setState(() => _viewerOpen = false);
    });
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
      onShare: () => DriveBulkActions.share(
        context,
        ref,
        fileIds: {fileId},
        folderIds: const {},
      ),
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
