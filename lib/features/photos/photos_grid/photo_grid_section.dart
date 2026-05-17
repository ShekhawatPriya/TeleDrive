import 'package:flutter/material.dart';

import '../photos_filter.dart';
import 'photo_date_grouping.dart';
import 'photo_tile.dart';

class PhotoGridSection extends StatelessWidget {
  const PhotoGridSection({
    required this.section,
    required this.columns,
    required this.filter,
    super.key,
  });

  final PhotoDateSection section;
  final int columns;
  final PhotosFilter filter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = columns >= 4 ? 2.0 : 3.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              section.label,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
                height: 1.2,
              ),
            ),
          ),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
            ),
            itemCount: section.files.length,
            itemBuilder: (_, i) =>
                PhotoTile(file: section.files[i], filter: filter),
          ),
        ],
      ),
    );
  }
}
