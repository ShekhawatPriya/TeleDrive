import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_tiles.dart';
import '../../widgets/media_thumb.dart';
import '../../widgets/tab_header.dart';
import '../drive/drive_controller.dart';

// ---------------------------------------------------------------------------
// Photos
// ---------------------------------------------------------------------------

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  String filter = 'all';
  final controller = ScrollController();

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (controller.position.pixels >
          controller.position.maxScrollExtent - 600) {
        ref.read(driveControllerProvider).loadMoreMedia();
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drive = ref.watch(driveControllerProvider);
    final files = drive.photoFiles(filter);
    final allMedia = drive.photoFiles('all');

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: controller,
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TabHeader(
                      title: 'Photos',
                      subtitle: allMedia.isEmpty
                          ? 'Your media library'
                          : '${allMedia.length} item${allMedia.length == 1 ? '' : 's'}',
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // ── Filter chips ────────────────────────────────────────
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'images', label: Text('Images')),
                    ButtonSegment(value: 'videos', label: Text('Videos')),
                    ButtonSegment(value: 'starred', label: Text('Starred')),
                  ],
                  selected: {filter},
                  onSelectionChanged: (value) =>
                      setState(() => filter = value.first),
                ),
              ),
            ),

            // ── Content ─────────────────────────────────────────────
            if (files.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: 'No media yet',
                  body: 'Images and videos appear here after upload.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                  itemCount:
                      files.length + (drive.state.loadingMoreMedia ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= files.length)
                      return const Center(child: CircularProgressIndicator());
                    return _PhotoTile(file: files[i]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.file});
  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/file/${file.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaThumb(file: file, fit: BoxFit.cover, radius: 10),
          if (isVideoFile(file))
            Positioned(
              right: 6,
              bottom: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Text(
                    file.duration == null
                        ? 'Video'
                        : formatDuration(file.duration!),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
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
            // ── Header ──────────────────────────────────────────────
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

            // ── Content ─────────────────────────────────────────────
            if (starred.files.isEmpty && starred.folders.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.star_border,
                  title: 'Nothing starred',
                  body: 'Star files and folders for quick access.',
                ),
              ),

            // Folders
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

            // Files
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
