import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'photo_date_grouping.dart';
import 'photo_tile.dart';
import 'justified_photo_layout.dart';

class PhotoGridSection extends StatefulWidget {
  const PhotoGridSection({
    required this.section,
    required this.columns,
    required this.selectMode,
    required this.selectedIds,
    required this.tileKeys,
    required this.onTileTap,
    required this.onTileLongPress,
    this.onTileSelect,
    this.square = false,
    super.key,
  });
  final PhotoDateSection section;
  final double columns;
  final bool square;
  final bool selectMode;
  final Set<String> selectedIds;
  final Map<String, GlobalKey> tileKeys;
  final void Function(String fileId) onTileTap;
  final ValueChanged<String>? onTileSelect;
  final void Function(String fileId, GlobalKey key) onTileLongPress;
  @override
  State<PhotoGridSection> createState() => PhotoGridSectionState();
}

class PhotoGridSectionState extends State<PhotoGridSection> {
  final _layouts = <int, PhotoLayout>{};
  double? _width, _gap;
  late Map<String, int> _indices = {
    for (var i = 0; i < widget.section.files.length; i++)
      widget.section.files[i].id: i,
  };
  PhotoLayout _layout(int columns) => _layouts.putIfAbsent(
    columns,
    () => layoutPhotos(
      widget.section.files,
      width: _width!,
      columns: columns,
      gap: _gap!,
      square: widget.square,
    ),
  );
  double? extentAt(double columns) {
    if (_width == null) return null;
    final from = _layout(columns.floor()), to = _layout(columns.ceil());
    return from.extent +
        (to.extent - from.extent) * (columns - columns.floor());
  }

  double? centerAt(String id, double columns) {
    final index = _indices[id];
    if (_width == null || index == null) return null;
    return Rect.lerp(
      _layout(columns.floor()).rects[index],
      _layout(columns.ceil()).rects[index],
      columns - columns.floor(),
    )!.center.dy;
  }

  @override
  void didUpdateWidget(PhotoGridSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.section.files, widget.section.files) ||
        oldWidget.square != widget.square) {
      _layouts.clear();
      _indices = {
        for (var i = 0; i < widget.section.files.length; i++)
          widget.section.files[i].id: i,
      };
    }
  }

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Semantics(
            header: true,
            child: Text(
              widget.section.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final gap = Theme.of(context).platform == TargetPlatform.iOS
                ? 4.0
                : 6.0;
            final width = constraints.crossAxisExtent;
            if (_width != width || _gap != gap) {
              _layouts.clear();
              _width = width;
              _gap = gap;
            }
            final low = widget.columns.floor(), high = widget.columns.ceil();
            return SliverGrid(
              gridDelegate: PhotoSliverGridDelegate(
                _layout(low),
                _layout(high),
                widget.columns - low,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final file = widget.section.files[index];
                final key = widget.tileKeys.putIfAbsent(file.id, GlobalKey.new);
                return PhotoTile(
                  key: key,
                  file: file,
                  selectMode: widget.selectMode,
                  selected: widget.selectedIds.contains(file.id),
                  onTap: () => widget.onTileTap(file.id),
                  onLongPress: () => widget.onTileLongPress(file.id, key),
                  onSelect: widget.onTileSelect == null
                      ? null
                      : () => widget.onTileSelect!(file.id),
                );
              }, childCount: widget.section.files.length),
            );
          },
        ),
      ),
    ],
  );
}
