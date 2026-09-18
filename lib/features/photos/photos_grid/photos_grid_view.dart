import 'package:flutter/material.dart';
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

  @override
  void didUpdateWidget(covariant PhotosGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
                  widget.onLoadMore();
                }
                return false;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (widget.showCover &&
                      !widget.selectMode &&
                      widget.files.isNotEmpty)
                    SliverToBoxAdapter(
                      child: PhotoLibraryCover(
                        file: widget.files.first,
                        onTap: () => widget.onTileTap(widget.files.first.id),
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
