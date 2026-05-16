import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_thumb.dart';
import '../drive/drive_controller.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      body: Column(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Expanded(
            child: files.isEmpty
                ? const EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'No media yet',
                    body: 'Images and videos appear here after upload.',
                  )
                : GridView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
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

class StarredScreen extends ConsumerWidget {
  const StarredScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starred = ref.watch(driveControllerProvider).starred();
    return Scaffold(
      appBar: AppBar(title: const Text('Starred')),
      body: starred.files.isEmpty && starred.folders.isEmpty
          ? const EmptyState(
              icon: Icons.star_border,
              title: 'Nothing starred',
              body: 'Star files and folders for quick access.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                for (final f in starred.folders)
                  ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(f.name),
                    onTap: () => context.push('/folder/${f.id}'),
                  ),
                for (final f in starred.files)
                  ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(f.name),
                    subtitle: Text(formatFileSize(f.size)),
                    onTap: () => context.push('/file/${f.id}'),
                  ),
              ],
            ),
    );
  }
}

class SharedScreen extends StatelessWidget {
  const SharedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shared')),
      body: const EmptyState(
        icon: Icons.group_outlined,
        title: 'Sharing is not enabled yet',
        body:
            'The backend contract currently keeps this area as a placeholder.',
      ),
    );
  }
}
