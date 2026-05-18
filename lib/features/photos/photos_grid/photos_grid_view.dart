import 'package:flutter/material.dart';

import '../../../models/drive_models.dart';
import 'photo_date_grouping.dart';
import 'photo_grid_density.dart';
import 'photo_grid_section.dart';
import 'photo_pan_selector.dart';

class PhotosGridView extends StatefulWidget {
  const PhotosGridView({
    required this.files,
    required this.density,
    required this.onLoadMore,
    required this.loadingMore,
    required this.selectMode,
    required this.selectedIds,
    required this.onTileTap,
    required this.onTileLongPress,
    required this.onTilePanSelect,
    super.key,
  });

  final List<DriveFile> files;
  final PhotoGridDensity density;
  final VoidCallback onLoadMore;
  final bool loadingMore;
  final bool selectMode;
  final Set<String> selectedIds;
  final void Function(String fileId) onTileTap;
  final void Function(String fileId, GlobalKey key) onTileLongPress;
  final void Function(String fileId) onTilePanSelect;

  @override
  State<PhotosGridView> createState() => _PhotosGridViewState();
}

class _PhotosGridViewState extends State<PhotosGridView> {
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.density,
      builder: (context, _) {
        final sections = groupByDate(widget.files);
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
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: sections.length + (widget.loadingMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= sections.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return PhotoGridSection(
                    section: sections[i],
                    columns: widget.density.columns,
                    selectMode: widget.selectMode,
                    selectedIds: widget.selectedIds,
                    tileKeys: _tileKeys,
                    onTileTap: widget.onTileTap,
                    onTileLongPress: widget.onTileLongPress,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
