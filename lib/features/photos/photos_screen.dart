import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/file_type_detector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_tiles.dart';
import '../../widgets/tab_header.dart';
import '../drive/drive_controller.dart';
import 'photos_filter.dart';
import 'photos_grid/photo_grid_density.dart';
import 'photos_grid/photos_grid_view.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final PhotoGridDensity _density = PhotoGridDensity();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _density.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drive = ref.watch(driveControllerProvider);
    final filter = _tabs.index == 0 ? PhotosFilter.photos : PhotosFilter.videos;
    final files = drive
        .photoFiles('all')
        .where(filter.accepts)
        .toList();
    final allCount = drive.photoFiles('all').length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TabHeader(
                title: 'Photos',
                subtitle: allCount == 0
                    ? 'Your media library'
                    : '$allCount item${allCount == 1 ? '' : 's'}',
              ),
            ),
            _PhotosTabBar(controller: _tabs),
            _PhotosToolbar(
              count: files.length,
              density: _density,
            ),
            Expanded(
              child: files.isEmpty
                  ? EmptyState(
                      icon: filter == PhotosFilter.videos
                          ? Icons.videocam_outlined
                          : Icons.photo_library_outlined,
                      title: filter == PhotosFilter.videos
                          ? 'No videos yet'
                          : 'No photos yet',
                      body: filter == PhotosFilter.videos
                          ? 'Videos appear here after upload.'
                          : 'Images appear here after upload.',
                    )
                  : PhotosGridView(
                      files: files,
                      density: _density,
                      filter: filter,
                      loadingMore: drive.state.loadingMoreMedia,
                      onLoadMore: () => ref
                          .read(driveControllerProvider)
                          .loadMoreMedia(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotosTabBar extends StatelessWidget {
  const _PhotosTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TabBar(
      controller: controller,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface.withValues(alpha: .55),
      indicatorColor: scheme.primary,
      indicatorWeight: 2.5,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      tabs: const [Tab(text: 'Photos'), Tab(text: 'Videos')],
    );
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
                onPressed:
                    density.columns >= density.max ? null : density.zoomOut,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Larger tiles',
                onPressed:
                    density.columns <= density.min ? null : density.zoomIn,
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
                        '${folder.recursiveFileCount} files • ${formatFileSize(folder.recursiveSize)}',
                    isFolder: true,
                    starred: true,
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
                          '${formatLabel(file)} • ${formatFileSize(file.size)} • ${formatDate(file.modifiedAt)}',
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TabHeader(
                title: 'Shared',
                subtitle: 'Files shared with you',
              ),
            ),
            const Expanded(
              child: EmptyState(
                icon: Icons.group_outlined,
                title: 'Sharing is not enabled yet',
                body:
                    'The backend contract currently keeps this area as a placeholder.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
