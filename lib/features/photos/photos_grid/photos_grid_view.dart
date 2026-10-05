import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

import '../../../models/drive_models.dart';
import 'photo_date_grouping.dart';
import '../components/photo_library_cover.dart';
import 'photo_grid_density.dart';
import 'photo_grid_section.dart';
import 'photo_pan_selector.dart';

class PhotosGridView extends StatefulWidget {
  const PhotosGridView({
    required this.files,
    this.showCover = true,
    required this.density,
    required this.onLoadMore,
    required this.loadingMore,
    required this.selectMode,
    required this.selectedIds,
    required this.onTileTap,
    required this.onTileLongPress,
    this.onTileSelect,
    required this.onTilePanSelect,
    super.key,
  });

  final List<DriveFile> files;
  final bool showCover;
  final PhotoGridDensity density;
  final VoidCallback onLoadMore;
  final bool loadingMore;
  final bool selectMode;
  final Set<String> selectedIds;
  final void Function(String fileId) onTileTap;
  final ValueChanged<String>? onTileSelect;
  final void Function(String fileId, GlobalKey key) onTileLongPress;
  final void Function(String fileId) onTilePanSelect;

  @override
  State<PhotosGridView> createState() => _PhotosGridViewState();
}

class _PhotosGridViewState extends State<PhotosGridView>
    with TickerProviderStateMixin {
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  late final AnimationController _densityAnimation;
  double _layoutColumns = 3, _pinchStartColumns = 3;
  late final AnimationController _reflowAnimation;
  double _paintedDensity = 3;
  bool _pinching = false;
  ui.Image? _snapshot;
  Offset _focalPoint = Offset.zero;
  String? _anchorId;
  double? _anchorY;
  int? _anchorSection;
  final _sectionKeys = <String, GlobalKey<PhotoGridSectionState>>{};

  ui.Image? _captureViewport() {
    final boundary = _viewportKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        (kDebugMode && boundary.debugNeedsPaint))
      return null;
    try {
      // One viewport only, at logical resolution. Never rasterise the library.
      return boundary.toImageSync(pixelRatio: 1);
    } catch (_) {
      return null;
    }
  }

  void _clearSnapshot() {
    final old = _snapshot;
    _snapshot = null;
    if (old != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _captureAnchor([Offset? focalPoint]) {
    final viewport = context.findRenderObject();
    if (viewport is! RenderBox) return;
    final origin = viewport.localToGlobal(Offset.zero);
    final target = focalPoint?.dy ?? origin.dy + viewport.size.height * .35;
    _focalPoint = focalPoint == null
        ? Offset(viewport.size.width / 2, viewport.size.height * .35)
        : focalPoint - origin;
    var closest = double.infinity;
    _anchorId = null;
    for (final entry in _tileKeys.entries) {
      final tile = entry.value.currentContext?.findRenderObject();
      if (tile is! RenderBox || !tile.attached) continue;
      final center = tile.localToGlobal(tile.size.center(Offset.zero)).dy;
      if (center < origin.dy || center > origin.dy + viewport.size.height)
        continue;
      final distance = (center - target).abs();
      if (distance < closest) {
        closest = distance;
        _anchorId = entry.key;
        _anchorY = center;
        if (focalPoint == null)
          _focalPoint =
              tile.localToGlobal(tile.size.center(Offset.zero)) - origin;
      }
    }
    _anchorSection = _anchorId == null
        ? null
        : _sections.indexWhere(
            (section) => section.files.any((file) => file.id == _anchorId),
          );
    if (_anchorSection == -1) _anchorSection = null;
  }

  void _changeLayout(double next) {
    final previous = _layoutColumns;
    _layoutColumns = next;
    if (_anchorId == null || _anchorSection == null || !_scroll.hasClients)
      return;
    var delta = 0.0;
    for (var i = 0; i < _anchorSection!; i++) {
      final section = _sectionKeys[_sections[i].label]?.currentState;
      delta +=
          (section?.extentAt(next) ?? 0) - (section?.extentAt(previous) ?? 0);
    }
    final section =
        _sectionKeys[_sections[_anchorSection!].label]?.currentState;
    delta +=
        (section?.centerAt(_anchorId!, next) ?? 0) -
        (section?.centerAt(_anchorId!, previous) ?? 0);
    _scroll.jumpTo(_scroll.offset + delta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _anchorY == null) return;
      final tile = _tileKeys[_anchorId]?.currentContext?.findRenderObject();
      if (tile is! RenderBox || !tile.attached) return;
      final center = tile.localToGlobal(tile.size.center(Offset.zero)).dy;
      final offset = (_scroll.offset + center - _anchorY!).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      if ((offset - _scroll.offset).abs() > .5) _scroll.jumpTo(offset);
    });
  }

  void _densityChanged() {
    if (_pinching) return;
    _densityAnimation.stop();
    _captureAnchor();
    _settleDensity();
  }

  void _visualDensityChanged() {
    final value = _densityAnimation.value.clamp(
      widget.density.min.toDouble(),
      widget.density.max.toDouble(),
    );
    final next = (value - .025)
        .ceil()
        .clamp(widget.density.min, widget.density.max)
        .toDouble();
    if (next == _layoutColumns) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final largeGestureStep =
        _pinching && (_paintedDensity / value - 1).abs() > .2;
    final image = reduced || largeGestureStep ? null : _captureViewport();
    _clearSnapshot();
    _snapshot = image;
    setState(() => _changeLayout(next));
    if (image != null) {
      _reflowAnimation.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted && _reflowAnimation.value == 1) setState(_clearSnapshot);
      });
    }
  }

  void _settleDensity() {
    final target = widget.density.columns.toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _densityAnimation.value = target;
    } else {
      _densityAnimation.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 450, damping: 42),
          _densityAnimation.value,
          target,
          0,
          tolerance: const Tolerance(distance: .001, velocity: .001),
        ),
      );
    }
  }

  void _pinchStart(Offset focalPoint) {
    _densityAnimation.stop();
    _pinchStartColumns = _densityAnimation.value;
    _captureAnchor(focalPoint);
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset);
    setState(() => _pinching = true);
  }

  void _pinchUpdate(double scale) {
    _densityAnimation.value = (_pinchStartColumns / scale).clamp(
      widget.density.min.toDouble(),
      widget.density.max.toDouble(),
    );
  }

  void _pinchEnd() {
    final target = _densityAnimation.value.round();
    widget.density.set(target);
    setState(() => _pinching = false);
    _settleDensity();
  }

  @override
  void dispose() {
    widget.density.removeListener(_densityChanged);
    _densityAnimation.dispose();
    _reflowAnimation.dispose();
    _snapshot?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  late List<PhotoDateSection> _sections = groupByDate(widget.files);
  DateTime _groupedDay = DateUtils.dateOnly(DateTime.now());
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};
  final _random = Random();
  final List<String> _highlightIds = [];
  int _highlightIndex = 0;

  void _updateHighlights() {
    final photos = widget.files
        .where((file) => file.kind == FileKind.image && !file.isOptimistic)
        .toList();
    final ids = photos.map((file) => file.id).toSet();
    _highlightIds.removeWhere((id) => !ids.contains(id));
    final remaining =
        photos.where((file) => !_highlightIds.contains(file.id)).toList()
          ..shuffle(_random);
    _highlightIds.addAll(
      remaining.take(5 - _highlightIds.length).map((file) => file.id),
    );
    if (_highlightIds.length > 1 && _highlightIds.first == photos.first.id) {
      final other = _highlightIds[1];
      _highlightIds[1] = _highlightIds.first;
      _highlightIds[0] = other;
    }
    _highlightIndex = _highlightIndex.clamp(
      0,
      max(0, _highlightIds.length - 1),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateHighlights();
    _layoutColumns = widget.density.columns.toDouble();
    _densityAnimation = AnimationController.unbounded(
      vsync: this,
      value: widget.density.columns.toDouble(),
    )..addListener(_visualDensityChanged);
    _paintedDensity = _layoutColumns;
    _reflowAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      value: 1,
    );
    widget.density.addListener(_densityChanged);
  }

  @override
  void didUpdateWidget(covariant PhotosGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.density != widget.density) {
      oldWidget.density.removeListener(_densityChanged);
      widget.density.addListener(_densityChanged);
      _densityChanged();
    }
    final today = DateUtils.dateOnly(DateTime.now());
    if (!listEquals(oldWidget.files, widget.files) || today != _groupedDay) {
      _updateHighlights();
      _anchorId = null;
      _anchorSection = null;
      _clearSnapshot();
      _sections = groupByDate(widget.files);
      _groupedDay = today;
      final ids = widget.files.map((file) => file.id).toSet();
      _tileKeys.removeWhere((id, _) => !ids.contains(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gallery = PhotoGridPinchDetector(
      onStart: _pinchStart,
      onUpdate: _pinchUpdate,
      onEnd: _pinchEnd,
      child: PhotoPanSelector(
        enabled: widget.selectMode,
        tileKeys: _tileKeys,
        onTilePan: widget.onTilePanSelect,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification &&
                n.dragDetails != null &&
                !_pinching) {
              _anchorId = null;
            }
            if (!_pinching &&
                !_densityAnimation.isAnimating &&
                !widget.loadingMore &&
                n is ScrollUpdateNotification &&
                n.metrics.axis == Axis.vertical &&
                n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
              widget.onLoadMore();
            }
            return false;
          },
          child: CustomScrollView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: _pinching
                ? const NeverScrollableScrollPhysics()
                : Theme.of(context).platform == TargetPlatform.iOS
                ? const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  )
                : const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
            slivers: [
              if (widget.showCover &&
                  !widget.selectMode &&
                  _highlightIds.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      SizedBox(
                        height:
                            264 +
                            (MediaQuery.textScalerOf(context).scale(24) - 24) *
                                2,
                        child: PageView.builder(
                          key: const ValueKey('photo-highlights'),
                          itemCount: _highlightIds.length,
                          onPageChanged: (index) =>
                              setState(() => _highlightIndex = index),
                          itemBuilder: (_, index) {
                            final file = widget.files.firstWhere(
                              (file) => file.id == _highlightIds[index],
                            );
                            return PhotoLibraryCover(
                              file: file,
                              onTap: () => widget.onTileTap(file.id),
                            );
                          },
                        ),
                      ),
                      if (_highlightIds.length > 1)
                        Semantics(
                          label:
                              'Highlight ${_highlightIndex + 1} of ${_highlightIds.length}',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < _highlightIds.length; i++)
                                Container(
                                  width: i == _highlightIndex ? 16 : 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: i == _highlightIndex
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              for (final section in _sections)
                PhotoGridSection(
                  key: _sectionKeys.putIfAbsent(
                    section.label,
                    () => GlobalKey<PhotoGridSectionState>(),
                  ),
                  section: section,
                  columns: _layoutColumns,
                  selectMode: widget.selectMode,
                  selectedIds: widget.selectedIds,
                  tileKeys: _tileKeys,
                  onTileTap: widget.onTileTap,
                  onTileLongPress: widget.onTileLongPress,
                  onTileSelect: widget.onTileSelect,
                ),
              if (widget.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_densityAnimation, _reflowAnimation]),
      child: gallery,
      builder: (context, child) {
        final value = _densityAnimation.value.clamp(
          widget.density.min.toDouble(),
          widget.density.max.toDouble(),
        );
        final reduced = MediaQuery.disableAnimationsOf(context);
        final liveScale = reduced && !_pinching
            ? 1.0
            : max(1.0, _layoutColumns / value);
        _paintedDensity = value;
        final snapshot = _snapshot;
        return RepaintBoundary(
          key: _viewportKey,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: liveScale,
                  origin: _focalPoint,
                  alignment: Alignment.topLeft,
                  child: child!,
                ),
                if (!reduced && snapshot != null && _reflowAnimation.value < 1)
                  IgnorePointer(
                    child: Opacity(
                      opacity: 1 - _reflowAnimation.value,
                      child: RawImage(image: snapshot, fit: BoxFit.fill),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
