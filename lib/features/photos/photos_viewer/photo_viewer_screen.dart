import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/drive_models.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/ios_more_menu.dart';
import '../../drive/components/drive_item_actions.dart';
import '../../drive/drive_controller.dart';
import '../../auth/auth_controller.dart';
import '../../file_viewer/file_open_action.dart';
import '../photos_filter.dart';
import 'photo_details_sheet.dart';
import 'photo_viewer_stage.dart';
import 'photo_viewer_filmstrip.dart';
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
  bool _downloading = false;
  final _stageKey = GlobalKey<PhotoViewerStageState>();
  String? _currentId;
  final Map<String, double> _aspectRatios = {};
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
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
    final retainedIndex = files.indexWhere((f) => f.id == _currentId);
    final initialIndex =
        (retainedIndex >= 0 ? retainedIndex : _currentIndex) ??
        () {
          final idx = files.indexWhere((f) => f.id == widget.startId);
          return idx < 0 ? 0 : idx;
        }();
    final index = initialIndex.clamp(0, files.length - 1);
    final current = files[index];
    _currentId = current.id;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: PhotoViewerStage(
        key: _stageKey,
        mediaAspectRatio:
            _aspectRatios[current.id] ??
            ((current.widthPx ?? 0) > 0 && (current.heightPx ?? 0) > 0
                ? current.widthPx! / current.heightPx!
                : null),
        detailsBuilder: (controller) => PhotoDetailsSheet(
          file: current,
          folderName: current.parentId == null
              ? null
              : drive.folder(current.parentId!)?.name,
          scrollController: controller,
          integrated: true,
        ),
        media: PhotoViewerPager(
          files: files,
          initialIndex: index,
          onDimensions: (id, dimensions) {
            if (!mounted || dimensions.height <= 0) return;
            final ratio = dimensions.width / dimensions.height;
            if (_aspectRatios[id] != ratio)
              setState(() => _aspectRatios[id] = ratio);
          },
          onPageChanged: (i) {
            setState(() {
              _currentIndex = i;
              _currentId = files[i].id;
            });
            final id = files[i].id;
            ref.read(driveControllerProvider).markAccessed(id);
          },
          onTapMedia: () {
            if (!(_stageKey.currentState?.isOpen ?? false))
              setState(() => _chromeVisible = !_chromeVisible);
          },
        ),
        header: PhotoViewerTopBar(
          file: current,
          visible: _chromeVisible,
          onBack: () => context.pop(),
          onStar: () =>
              ref.read(driveControllerProvider).toggleStar(current.id),
          onInfo: () => _openInfo(context, current),
          onDownload: () => _download(context, current),
          onMore: () => _openMore(context, current),
          menuSections: (_) {
            final owner = ref.read(authControllerProvider).user;
            return [
              for (final destructive in [false, true])
                IosMenuSection([
                  for (final action in DriveItemActions.fileActions(
                    current,
                  ).where((a) => a.destructive == destructive))
                    IosMenuItem(
                      label: action.label,
                      destructive: action.destructive,
                      onTap: () {
                        if (!mounted) return;
                        final active = ref.read(authControllerProvider).user;
                        if (active?.userId != owner?.userId ||
                            active?.telegramId != owner?.telegramId)
                          return;
                        DriveItemActions.performFileAction(
                          context,
                          ref,
                          current,
                          action.id,
                        );
                      },
                    ),
                ]),
            ];
          },
        ),
        footer: AnimatedOpacity(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          opacity: _chromeVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_chromeVisible,
            child: ExcludeSemantics(
              excluding: !_chromeVisible,
              child: ColoredBox(
                color: Theme.of(context).platform == TargetPlatform.android
                    ? Colors.black
                    : Colors.transparent,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!(_stageKey.currentState?.isOpen ?? false))
                        PhotoViewerFilmstrip(
                          files: files,
                          index: index,
                          onSelected: (i) {
                            setState(() {
                              _currentIndex = i;
                              _currentId = files[i].id;
                            });
                            drive.markAccessed(files[i].id);
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
                        child: PhotoViewerActions(
                          file: current,
                          infoSelected: _stageKey.currentState?.isOpen ?? false,
                          onStar: () => drive.toggleStar(current.id),
                          onInfo: () => _openInfo(context, current),
                          onDownload: () => _download(context, current),
                          onShare: () => DriveItemActions.performFileAction(
                            context,
                            ref,
                            current,
                            'share',
                          ),
                          onDelete: () => DriveItemActions.performFileAction(
                            context,
                            ref,
                            current,
                            'delete',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        onDetailsChanged: () {
          if (mounted) setState(() => _chromeVisible = true);
        },
      ),
    );
  }

  void _openInfo(BuildContext context, DriveFile file) {
    _stageKey.currentState?.toggle();
  }

  Future<void> _download(BuildContext context, DriveFile file) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await openDriveFileExternally(
        context,
        ref,
        file,
        returnTo: '/photos/view/${file.id}',
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
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
