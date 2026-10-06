// Simulator-only fixture. All actions stay local; no live account is loaded.
import 'dart:io';
import 'package:flutter_m_fsdk/features/photos/components/photos_library_controls.dart';
import 'package:flutter_m_fsdk/features/photos/photos_filter.dart';
import 'package:flutter_m_fsdk/features/search/search_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_m_fsdk/core/media/photo_media_loader.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/photos_grid_view.dart';
import 'package:flutter_m_fsdk/features/photos/photos_grid/photo_grid_density.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_filmstrip.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/models/auth_user.dart';
import 'package:flutter_m_fsdk/features/share/share_flow.dart';
import 'package:flutter_m_fsdk/features/share/file_copy_share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_m_fsdk/core/theme/app_theme.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_details_sheet.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_pager.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_stage.dart';
import 'package:flutter_m_fsdk/features/photos/photos_viewer/photo_viewer_top_bar.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

final _fixtureLight = ValueNotifier(false);
final _fixtureAccessible = ValueNotifier(false);
final _fixtureNarrow = ValueNotifier(false);

void main() {
  final auth = _FixtureAuth();
  runApp(
    ProviderScope(
      overrides: [
        driveControllerProvider.overrideWith((_) => _LocalDrive()),
        photoMediaLoaderProvider.overrideWithValue(_LocalMedia()),
        authControllerProvider.overrideWith((_) => auth),
        fileCopyShareServiceProvider.overrideWithValue(
          FileCopyShareService(
            stage: (source, file, name, token) => stageOriginalForSharing(
              source,
              file,
              name,
              token,
              backend: 'fixture',
              userId: 1,
              telegramId: 10,
            ),
            auth: auth,
            download: (file, _, __) async => File(file.previewUrl!),
          ),
        ),
      ],
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _fixtureLight,
          _fixtureAccessible,
          _fixtureNarrow,
        ]),
        builder: (context, _) => MaterialApp(
          theme: buildTheme(
            AppBrand.scheme(
              _fixtureLight.value ? Brightness.light : Brightness.dark,
            ),
          ).copyWith(platform: TargetPlatform.iOS),
          builder: (context, child) => Center(
            child: SizedBox(
              width: _fixtureNarrow.value ? 320 : null,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    _fixtureAccessible.value ? 2 : 1,
                  ),
                  disableAnimations: _fixtureAccessible.value,
                  highContrast: _fixtureAccessible.value,
                ),
                child: child!,
              ),
            ),
          ),
          home: const _Preview(),
        ),
      ),
    ),
  );
}

class _Preview extends ConsumerStatefulWidget {
  const _Preview();
  @override
  ConsumerState<_Preview> createState() => _PreviewState();
}

class _PreviewState extends ConsumerState<_Preview> {
  final stage = GlobalKey<PhotoViewerStageState>();
  double? aspect;
  bool zoomed = false;
  String lastAction = 'Photo viewer fixture';
  DriveFile file = DriveFile(
    id: 'fixture',
    name: 'Alpine afternoon.jpg',
    kind: FileKind.image,
    size: File(const String.fromEnvironment('PHOTO_PREVIEW_PATH')).lengthSync(),
    mimeType: 'image/jpeg',
    modifiedAt: '2026-09-17',
    createdAt: '2026-09-17',
    parentId: null,
    starred: false,
    previewUrl: File(const String.fromEnvironment('PHOTO_PREVIEW_PATH')).path,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: PhotoViewerStage(
      key: stage,
      mediaAspectRatio: aspect,
      mediaZoomed: zoomed,
      onDetailsChanged: () => setState(() {}),
      media: PhotoViewerPager(
        files: [file],
        initialIndex: 0,
        onPageChanged: (_) {},
        onTapMedia: () {},
        onDimensions: (_, size) =>
            setState(() => aspect = size.width / size.height),
        onZoomChanged: (_, value) => setState(() => zoomed = value),
      ),
      header: ref.watch(shareFlowStateProvider).busy
          ? const SizedBox.shrink()
          : SafeArea(
              child: Column(
                children: [
                  Text(lastAction, style: const TextStyle(color: Colors.white)),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _FixtureGallery(),
                      ),
                    ),
                    child: const Text('Browse fixture library'),
                  ),
                ],
              ),
            ),
      detailsBuilder: (scroll) => PhotoDetailsSheet(
        file: file,
        folderName: null,
        scrollController: scroll,
        integrated: true,
      ),
      footer: ref.watch(shareFlowStateProvider).busy
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 8,
                ),
                child: PhotoViewerActions(
                  file: file,
                  infoSelected: stage.currentState?.isOpen ?? false,
                  onStar: () => setState(
                    () => file = file.copyWith(starred: !file.starred),
                  ),
                  onInfo: () => stage.currentState?.toggle(),
                  onDownload: () {},
                  onShare: () => openItemShare(context, ref, files: [file]),
                  onDelete: () =>
                      setState(() => lastAction = 'Fixture delete tapped'),
                ),
              ),
            ),
    ),
  );
}

class _FixtureAuth extends ChangeNotifier implements AuthController {
  @override
  AuthUser get user =>
      const AuthUser(userId: 1, telegramId: 10, firstName: 'Fixture');
  @override
  String get token => 'fixture';
  @override
  bool get switchingAccount => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _LocalMedia implements PhotoMediaLoader {
  @override
  String revision(DriveFile file) => file.id;
  @override
  Future<String> video(
    DriveFile file,
    CancelToken token, {
    ProgressCallback? progress,
  }) async => file.streamUrl!;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Local fixture only');
}

class _FixtureGallery extends ConsumerStatefulWidget {
  const _FixtureGallery();
  @override
  ConsumerState<_FixtureGallery> createState() => _FixtureGalleryState();
}

class _FixtureGalleryState extends ConsumerState<_FixtureGallery> {
  final grid = GlobalKey<PhotosGridViewState>();
  final density = PhotoGridDensity();
  PhotosFilter filter = PhotosFilter.all;
  late final files = [
    for (var i = 0; i < 36; i++)
      DriveFile(
        id: 'gallery-$i',
        name: i == 1 ? 'Fixture video.mp4' : 'Fixture photo $i.jpg',
        kind: i == 1 ? FileKind.video : FileKind.image,
        size: 0,
        modifiedAt: '2026-10-01',
        createdAt: '2026-10-01',
        parentId: null,
        starred: false,
        widthPx: i % 3 == 0 ? 900 : 1600,
        heightPx: i % 3 == 0 ? 1600 : 900,
        thumbnailUrl: const String.fromEnvironment('PHOTO_PREVIEW_PATH'),
        previewUrl: const String.fromEnvironment('PHOTO_PREVIEW_PATH'),
        streamUrl: i == 1
            ? const String.fromEnvironment('VIDEO_PREVIEW_PATH')
            : null,
      ),
  ];
  @override
  void dispose() {
    density.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider(SearchScope.photos)).query;
    final visible = files
        .where(
          (file) =>
              filter.accepts(file) && file.name.toLowerCase().contains(query),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: PhotosGridView(
          key: grid,
          files: visible,
          density: density,
          onLoadMore: () {},
          loadingMore: false,
          selectMode: false,
          selectedIds: const {},
          onTilePanSelect: (_) {},
          onTileLongPress: (_, _) {},
          leadingSlivers: [
            const SliverToBoxAdapter(child: Text('Photos library fixture')),
            SliverToBoxAdapter(
              child: Wrap(
                children: [
                  TextButton(
                    onPressed: () => _fixtureLight.value = !_fixtureLight.value,
                    child: const Text('Fixture light theme'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _fixtureNarrow.value = !_fixtureNarrow.value,
                    child: const Text('Fixture 320 points'),
                  ),
                  TextButton(
                    onPressed: () =>
                        _fixtureAccessible.value = !_fixtureAccessible.value,
                    child: const Text('Fixture large text'),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PhotosLibraryControls(
                  filter: filter,
                  onFilterChanged: (value) => setState(() => filter = value),
                ),
              ),
            ),
          ],
          onTileTap: (id) {
            final origin = grid.currentState?.sourceRect(id);
            Navigator.of(context).push(
              PageRouteBuilder<void>(
                opaque: false,
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => _GalleryViewer(
                  files: visible,
                  initial: visible.indexWhere((f) => f.id == id),
                  source: origin,
                  reveal: (current) async =>
                      grid.currentState?.revealFile(current),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({
    required this.files,
    required this.initial,
    required this.source,
    required this.reveal,
  });
  final List<DriveFile> files;
  final int initial;
  final Rect? source;
  final Future<Rect?> Function(String) reveal;
  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  final stage = GlobalKey<PhotoViewerStageState>();
  late int index = widget.initial;
  bool moving = true, native = false, zoomed = false, scrub = false;
  Size? dimensions;
  @override
  Widget build(BuildContext context) {
    final file = widget.files[index];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PhotoViewerStage(
        key: stage,
        sourceRect: widget.source,
        prepareDismiss: () => widget.reveal(widget.files[index].id),
        onDismissed: () => Navigator.pop(context),
        onInteractionChanged: (value) => setState(() => moving = value),
        mediaZoomed: zoomed,
        nativeVideo: native && file.kind == FileKind.video,
        mediaAspectRatio: dimensions == null
            ? file.widthPx! / file.heightPx!
            : dimensions!.aspectRatio,
        onDetailsChanged: () => setState(() {}),
        media: PhotoViewerPager(
          files: widget.files,
          initialIndex: index,
          active: !moving && !scrub,
          onPageChanged: (i) => setState(() {
            index = i;
            native = false;
            zoomed = false;
            dimensions = null;
          }),
          onTapMedia: () {},
          onZoomChanged: (_, value) => setState(() => zoomed = value),
          onDimensions: (_, value) => setState(() => dimensions = value),
          onNativeChanged: (id, value) {
            if (id == file.id) setState(() => native = value);
          },
          onNativeDrag: (phase, position, velocity) =>
              stage.currentState?.nativeDrag(phase, position, velocity),
        ),
        header: SafeArea(
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to fixture library',
                onPressed: () => stage.currentState?.dismiss(),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(child: Text(file.name)),
            ],
          ),
        ),
        detailsBuilder: (scroll) => PhotoDetailsSheet(
          file: file,
          folderName: null,
          scrollController: scroll,
          integrated: true,
        ),
        footer: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhotoViewerFilmstrip(
                files: widget.files,
                index: index,
                onSelected: (i) => setState(() => index = i),
                onScrubbingChanged: (value) => setState(() => scrub = value),
              ),
              PhotoViewerActions(
                file: file,
                onStar: () {},
                onInfo: () => stage.currentState?.toggle(),
                onDownload: () {},
                onDelete: () {},
                infoSelected: stage.currentState?.isOpen ?? false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalDrive extends ChangeNotifier implements DriveController {
  @override
  DriveFile? file(String id) => null;
  @override
  DriveFolder? folder(String id) => null;
  @override
  int get accountGeneration => 0;
  @override
  Future<void> toggleStar(String id, {bool folder = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Local fixture only');
}
