import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/drive_models.dart';
import '../../../core/utils/file_type_detector.dart';
import 'photo_viewer_session.dart';
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
import '../../share/share_flow.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    required this.startId,
    required this.filter,
    this.query = '',
    this.session,
    super.key,
  });

  final String startId;
  final PhotosFilter filter;
  final String query;
  final PhotoViewerSession? session;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  bool _chromeVisible = true;
  bool _nativeFullscreen = false;
  final Set<String> _nativeVideos = {};
  bool _downloading = false;
  bool _initialResolving = false;
  bool _initialFailed = false;
  DriveFile? _linkedFile;
  final _stageKey = GlobalKey<PhotoViewerStageState>();
  late final PhotoViewerSession _session;
  bool _transitioning = true, _scrubbing = false, _exitQueued = false;
  final Map<String, double> _aspectRatios = {};
  final Map<String, bool> _zoomed = {};

  @override
  void initState() {
    super.initState();
    _session =
        widget.session ??
        PhotoViewerSession(
          filter: widget.filter,
          query: widget.query,
          currentId: widget.startId,
          generation: ref.read(driveControllerProvider).accountGeneration,
        );
    if (widget.session == null &&
        !ref
            .read(driveControllerProvider)
            .photoFiles('all')
            .any((f) => f.id == widget.startId)) {
      _initialResolving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveInitial());
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }

  void _leaveViewer() {
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.maybePop(context);
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go('/photos');
    }
  }

  Future<void> _resolveInitial() async {
    final drive = ref.read(driveControllerProvider);
    final file = await drive.ensureFileLoaded(widget.startId);
    if (!mounted || drive.accountGeneration != _session.generation) return;
    setState(() {
      _linkedFile = file != null && widget.filter.accepts(file) ? file : null;
      _initialFailed = _linkedFile == null;
      _initialResolving = false;
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sharing = ref.watch(
      shareFlowStateProvider.select((state) => state.busy),
    );
    final drive = ref.watch(driveControllerProvider);
    final valid =
        ref.read(driveControllerProvider).accountGeneration ==
        _session.generation;
    if (valid && _initialResolving) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (valid && _initialFailed) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Photo unavailable'),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _leaveViewer,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: TextButton(
            onPressed: () {
              setState(() => _initialResolving = true);
              _resolveInitial();
            },
            child: const Text('Try again'),
          ),
        ),
      );
    }
    final loaded = drive.photoFiles('all');
    final linked = _linkedFile == null ? null : drive.file(_linkedFile!.id);
    final files = valid
        ? _session.reconcile([
            ...loaded,
            if (linked != null && !loaded.any((f) => f.id == linked.id)) linked,
          ])
        : <DriveFile>[];
    if (files.isEmpty) {
      if (!_exitQueued) {
        _exitQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _leaveViewer();
        });
      }
      return _emptyScaffold(context, 'No media to display.');
    }
    final index = _session.index;
    final current = files[index];
    final currentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final playbackActive =
        currentRoute && !sharing && !_transitioning && !_scrubbing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: PhotoViewerStage(
        key: _stageKey,
        sourceRect: _session.sourceRect?.call(current.id),
        prepareDismiss: () async =>
            _session.revealSource?.call(_session.currentId),
        onDismissed: () {
          if (mounted) _leaveViewer();
        },
        onInteractionChanged: (value) {
          if (mounted) setState(() => _transitioning = value);
        },
        gesturesEnabled: !sharing && currentRoute,
        nativeVideo: _nativeVideos.contains(current.id) && isVideoFile(current),
        mediaZoomed: _zoomed[current.id] ?? false,
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
          active: playbackActive,
          onNativeChanged: (id, value) {
            if (mounted)
              setState(() {
                if (value) {
                  _nativeVideos.add(id);
                } else {
                  _nativeVideos.remove(id);
                }
              });
          },
          onFullscreen: (value) {
            if (mounted) setState(() => _nativeFullscreen = value);
          },
          onNativeDrag: (phase, point, velocity) =>
              _stageKey.currentState?.nativeDrag(phase, point, velocity),
          onZoomChanged: (id, zoomed) {
            if (mounted && _zoomed[id] != zoomed) {
              setState(() => _zoomed[id] = zoomed);
            }
          },
          onDimensions: (id, dimensions) {
            if (!mounted || dimensions.height <= 0) return;
            final ratio = dimensions.width / dimensions.height;
            if (_aspectRatios[id] != ratio)
              setState(() => _aspectRatios[id] = ratio);
          },
          onPageChanged: (i) {
            setState(() {
              _session.select(i);
            });
            final id = files[i].id;
            ref.read(driveControllerProvider).markAccessed(id);
          },
          onTapMedia: () {
            if (!(_stageKey.currentState?.isOpen ?? false))
              setState(() => _chromeVisible = !_chromeVisible);
          },
        ),
        header: sharing || _nativeFullscreen
            ? const SizedBox.shrink()
            : PhotoViewerTopBar(
                file: current,
                visible: _chromeVisible,
                onBack: () => _stageKey.currentState?.dismiss(),
                onStar: () =>
                    ref.read(driveControllerProvider).toggleStar(current.id),
                onInfo: () => _openInfo(context, current),
                onDownload: () => _download(context, current),
                onMore: () => _openMore(context, current),
                menuSections: (_) {
                  final owner = ref.read(authControllerProvider).user;
                  final latest =
                      ref
                          .read(driveControllerProvider)
                          .file(_session.currentId) ??
                      current;
                  return [
                    for (final destructive in [false, true])
                      IosMenuSection([
                        for (final action in DriveItemActions.fileActions(
                          latest,
                        ).where((a) => a.destructive == destructive))
                          IosMenuItem(
                            label: action.label,
                            destructive: action.destructive,
                            onTap: () {
                              if (!mounted) return;
                              final active = ref
                                  .read(authControllerProvider)
                                  .user;
                              if (active?.userId != owner?.userId ||
                                  active?.telegramId != owner?.telegramId)
                                return;
                              DriveItemActions.performFileAction(
                                context,
                                ref,
                                ref
                                        .read(driveControllerProvider)
                                        .file(latest.id) ??
                                    latest,
                                action.id,
                              );
                            },
                          ),
                      ]),
                  ];
                },
              ),
        footer: sharing || _nativeFullscreen
            ? const SizedBox.shrink()
            : AnimatedOpacity(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                opacity: _chromeVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: ExcludeSemantics(
                    excluding: !_chromeVisible,
                    child: ColoredBox(
                      color:
                          Theme.of(context).platform == TargetPlatform.android
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
                                onScrubbingChanged: (value) {
                                  if (mounted)
                                    setState(() => _scrubbing = value);
                                },
                                onSelected: (i) {
                                  setState(() {
                                    _session.select(i);
                                  });
                                  drive.markAccessed(files[i].id);
                                },
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
                              child: PhotoViewerActions(
                                file: current,
                                infoSelected:
                                    _stageKey.currentState?.isOpen ?? false,
                                onStar: () => drive.toggleStar(current.id),
                                onInfo: () => _openInfo(context, current),
                                onDownload: () => _download(context, current),
                                onShare: () =>
                                    DriveItemActions.performFileAction(
                                      context,
                                      ref,
                                      current,
                                      'share',
                                    ),
                                onDelete: () =>
                                    DriveItemActions.performFileAction(
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
        returnTo: Uri(
          path: '/photos/view/${file.id}',
          queryParameters: {
            'filter': _session.filter.queryValue,
            if (_session.query.isNotEmpty) 'q': _session.query,
          },
        ).toString(),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openMore(BuildContext context, DriveFile file) async {
    await DriveItemActions.openFile(context, ref, file);
  }

  Widget _emptyScaffold(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _leaveViewer,
          icon: const Icon(Icons.arrow_back),
        ),
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
