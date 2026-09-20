import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

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

class _PhotosGridViewState extends State<PhotosGridView> {
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
  }

  @override
  void didUpdateWidget(covariant PhotosGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateHighlights();
    final today = DateUtils.dateOnly(DateTime.now());
    if (!listEquals(oldWidget.files, widget.files) || today != _groupedDay) {
      _sections = groupByDate(widget.files);
      _groupedDay = today;
      final ids = widget.files.map((file) => file.id).toSet();
      _tileKeys.removeWhere((id, _) => !ids.contains(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.density,
      builder: (context, _) {
        return PhotoGridPinchDetector(
          density: widget.density,
          child: PhotoPanSelector(
            enabled: widget.selectMode,
            tileKeys: _tileKeys,
            onTilePan: widget.onTilePanSelect,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.axis == Axis.vertical &&
                    n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
                  widget.onLoadMore();
                }
                return false;
              },
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
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
                                (MediaQuery.textScalerOf(context).scale(24) -
                                        24) *
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
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
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
                      section: section,
                      columns: widget.density.columns,
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
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
