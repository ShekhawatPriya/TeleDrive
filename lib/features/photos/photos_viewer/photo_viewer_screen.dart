import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../models/drive_models.dart';
import '../../../widgets/empty_state.dart';
import '../../auth/auth_controller.dart';
import '../../drive/components/drive_item_actions.dart';
import '../../drive/drive_controller.dart';
import '../photos_filter.dart';
import 'photo_details_sheet.dart';
import 'photo_viewer_pager.dart';
import 'photo_viewer_top_bar.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    required this.startId,
    required this.filter,
    super.key,
  });

  final String startId;
  final PhotosFilter filter;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  bool _chromeVisible = true;
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [SystemUiOverlay.top],
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  List<DriveFile> _resolveFiles() {
    final drive = ref.read(driveControllerProvider);
    return drive.photoFiles('all').where(widget.filter.accepts).toList();
  }

  @override
  Widget build(BuildContext context) {
    final drive = ref.watch(driveControllerProvider);
    final files = drive.photoFiles('all').where(widget.filter.accepts).toList();
    if (files.isEmpty) {
      return _emptyScaffold(context, 'No media to display.');
    }
    final initialIndex = _currentIndex ??
        () {
          final idx = files.indexWhere((f) => f.id == widget.startId);
          return idx < 0 ? 0 : idx;
        }();
    final current = files[initialIndex.clamp(0, files.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          PhotoViewerPager(
            files: files,
            initialIndex: initialIndex,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              final id = files[i].id;
              ref.read(driveControllerProvider).markAccessed(id);
            },
            onTapMedia: () => setState(() => _chromeVisible = !_chromeVisible),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PhotoViewerTopBar(
              file: current,
              visible: _chromeVisible,
              onBack: () => context.pop(),
              onStar: () => ref
                  .read(driveControllerProvider)
                  .toggleStar(current.id),
              onInfo: () => _openInfo(context, current),
              onDownload: () => _download(context, current),
              onMore: () => _openMore(context, current),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _chromeVisible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_chromeVisible,
                child: SafeArea(
                  top: false,
                  child: GestureDetector(
                    onTap: () => _openInfo(context, current),
                    onVerticalDragUpdate: (d) {
                      if (d.primaryDelta != null && d.primaryDelta! < -6) {
                        _openInfo(context, current);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_arrow_up,
                              color: Colors.white70, size: 20),
                          SizedBox(height: 2),
                          Text(
                            'Swipe up for details',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInfo(BuildContext context, DriveFile file) async {
    final folderName = file.parentId == null
        ? null
        : ref.read(driveControllerProvider).folder(file.parentId!)?.name;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, controller) => PhotoDetailsSheet(
          file: file,
          folderName: folderName,
          scrollController: controller,
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, DriveFile file) async {
    final url = file.downloadUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );
      final api = ref.read(apiClientProvider);
      final dir = await getTemporaryDirectory();
      final safeName = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '${dir.path}/$safeName';
      await api.dio.download(url, path);
      await OpenFilex.open(path);
    } catch (err) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref.read(apiClientProvider).errorMessage(err, 'Download failed.'),
          ),
        ),
      );
    }
  }

  Future<void> _openMore(BuildContext context, DriveFile file) async {
    final wasFiles = _resolveFiles();
    await DriveItemActions.openFile(context, ref, file);
    if (!mounted) return;
    final remaining = _resolveFiles();
    if (remaining.length < wasFiles.length && context.mounted) {
      context.pop();
    }
  }

  Widget _emptyScaffold(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: EmptyState(
        icon: Icons.image_not_supported_outlined,
        title: 'Nothing to show',
        body: message,
      ),
    );
  }
}
