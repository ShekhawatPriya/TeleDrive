import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/utils/file_type_detector.dart';
import '../../models/drive_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_thumb.dart';
import '../auth/auth_controller.dart';
import '../drive/drive_controller.dart';

class FileViewerScreen extends ConsumerWidget {
  const FileViewerScreen({required this.fileId, super.key});
  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveControllerProvider);
    final file = drive.file(fileId);
    if (file == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'File not found',
          body: 'Refresh Drive and try again.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(driveControllerProvider).toggleStar(file.id),
            icon: Icon(file.starred ? Icons.star : Icons.star_border),
          ),
          IconButton(
            onPressed: () => _download(context, ref, file),
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AspectRatio(
            aspectRatio:
                file.widthPx != null &&
                    file.heightPx != null &&
                    file.heightPx! > 0
                ? file.widthPx! / file.heightPx!
                : 1,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: isVideoFile(file) && file.streamUrl != null
                    ? _VideoPlayer(url: file.streamUrl!)
                    : MediaThumb(file: file, fit: BoxFit.contain, radius: 14),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(file.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '${formatLabel(file)} • ${formatFileSize(file.size)} • ${formatDate(file.modifiedAt)}',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Meta(label: 'MIME type', value: file.mimeType ?? 'Unknown'),
                  _Meta(
                    label: 'Upload status',
                    value: file.uploadStatus ?? 'available',
                  ),
                  _Meta(
                    label: 'Preview',
                    value: file.previewStatus ?? 'not available',
                  ),
                  if (file.duration != null)
                    _Meta(
                      label: 'Duration',
                      value: formatDuration(file.duration!),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    DriveFile file,
  ) async {
    final url = file.downloadUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Downloading...')));
      final api = ref.read(apiClientProvider);
      final dir = await getTemporaryDirectory();
      final safeName = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '${dir.path}/$safeName';
      await api.dio.download(url, path);
      await OpenFilex.open(path);
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref.read(apiClientProvider).errorMessage(err, 'Download failed.'),
          ),
        ),
      );
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.url});
  final String url;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? video;
  ChewieController? chewie;
  Object? error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        video = controller;
        chewie = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
        );
      });
    } catch (err) {
      setState(() => error = err);
    }
  }

  @override
  void dispose() {
    chewie?.dispose();
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null)
      return const Center(child: Icon(Icons.video_file_outlined, size: 48));
    final c = chewie;
    if (c == null) return const Center(child: CircularProgressIndicator());
    return Chewie(controller: c);
  }
}
