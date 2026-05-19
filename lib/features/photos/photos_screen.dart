import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_tiles.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/auth_controller.dart';
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
    final auth = ref.watch(authControllerProvider);
    final drive = ref.watch(driveControllerProvider);
    final files = drive.photoFiles('all');
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
                    SliverAppBar.medium(
                      pinned: true,
                      expandedHeight: 128,
                      title: Text(
                        'Photos',
                        style: theme.textTheme.titleLarge,
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        title: Text(
                          allCount == 0
                              ? 'Your media library'
                              : '$allCount item${allCount == 1 ? '' : 's'}',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      actions: [
                        AnimatedBuilder(
                          animation: _density,
                          builder: (_, __) => IconButton(
                            tooltip: 'Smaller tiles',
                            onPressed: _density.columns >= _density.max
                                ? null
                                : _density.zoomOut,
                            icon: const Icon(Icons.grid_view_rounded),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _density,
                          builder: (_, __) => IconButton(
                            tooltip: 'Larger tiles',
                            onPressed: _density.columns <= _density.min
                                ? null
                                : _density.zoomIn,
                            icon: const Icon(Icons.grid_on_rounded),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              0, 0, AppSpacing.sm, 0),
                          child: GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: ProfileAvatar(user: auth.user, size: 36),
                          ),
                        ),
                      ],
                    ),
                  if (files.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.photo_library_outlined,
                        title: 'No photos yet',
                        body: 'Photos and videos appear here after upload.',
                      ),
                    )
                  else
                    SliverFillRemaining(
                      child: PhotosGridView(
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
    final auth = ref.watch(authControllerProvider);
    final drive = ref.watch(driveControllerProvider);
    final starred = drive.starred();
    final totalItems = starred.files.length + starred.folders.length;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            pinned: true,
            expandedHeight: 128,
            title: Text('Starred', style: theme.textTheme.titleLarge),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              title: Text(
                totalItems == 0
                    ? 'Quick access to favourites'
                    : '$totalItems item${totalItems == 1 ? '' : 's'}',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    0, 0, AppSpacing.sm, 0),
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: ProfileAvatar(user: auth.user, size: 36),
                ),
              ),
            ],
          ),
          if (starred.files.isEmpty && starred.folders.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.star_border_rounded,
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
                      '${folder.recursiveFileCount} files · ${formatFileSize(folder.recursiveSize)}',
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
                        '${formatLabel(file)} · ${formatFileSize(file.size)} · ${formatDate(file.modifiedAt)}',
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
