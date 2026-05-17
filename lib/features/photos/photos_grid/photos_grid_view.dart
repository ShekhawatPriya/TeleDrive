import 'package:flutter/material.dart';

import '../../../models/drive_models.dart';
import '../photos_filter.dart';
import 'photo_date_grouping.dart';
import 'photo_grid_density.dart';
import 'photo_grid_section.dart';

class PhotosGridView extends StatelessWidget {
  const PhotosGridView({
    required this.files,
    required this.density,
    required this.filter,
    required this.onLoadMore,
    required this.loadingMore,
    super.key,
  });

  final List<DriveFile> files;
  final PhotoGridDensity density;
  final PhotosFilter filter;
  final VoidCallback onLoadMore;
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: density,
      builder: (context, _) {
        final sections = groupByDate(files);
        return PhotoGridPinchDetector(
          density: density,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
                onLoadMore();
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: sections.length + (loadingMore ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= sections.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return PhotoGridSection(
                  section: sections[i],
                  columns: density.columns,
                  filter: filter,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
