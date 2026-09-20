import 'package:flutter/material.dart';

import 'photo_date_grouping.dart';
import 'photo_tile.dart';
import 'justified_photo_layout.dart';

class PhotoGridSection extends StatelessWidget {
  const PhotoGridSection({
    required this.section,
    required this.columns,
    required this.selectMode,
    required this.selectedIds,
    required this.tileKeys,
    required this.onTileTap,
    required this.onTileLongPress,
    this.onTileSelect,
    super.key,
  });

  final PhotoDateSection section;
  final int columns;
  final bool selectMode;
  final Set<String> selectedIds;
  final Map<String, GlobalKey> tileKeys;
  final void Function(String fileId) onTileTap;
  final ValueChanged<String>? onTileSelect;
  final void Function(String fileId, GlobalKey key) onTileLongPress;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        // Preserve the chosen phone density while adding columns on larger screens.
        final spacing = Theme.of(context).platform == TargetPlatform.iOS
            ? 4.0
            : 6.0;
        final rows = justifyPhotos(
          section.files,
          width: constraints.crossAxisExtent - 40,
          targetHeight: (390 / columns).clamp(84, 210),
          gap: spacing,
        );
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Semantics(
                  header: true,
                  child: Text(
                    section.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final row = rows[i];
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: SizedBox(
                      height: row.height,
                      child: Row(
                        children: [
                          for (var j = 0; j < row.files.length; j++) ...[
                            if (j > 0) SizedBox(width: spacing),
                            SizedBox(
                              width: row.widths[j],
                              child: Builder(
                                builder: (_) {
                                  final file = row.files[j];
                                  final key = tileKeys.putIfAbsent(
                                    file.id,
                                    () => GlobalKey(),
                                  );
                                  return PhotoTile(
                                    key: key,
                                    file: file,
                                    selectMode: selectMode,
                                    selected: selectedIds.contains(file.id),
                                    onTap: () => onTileTap(file.id),
                                    onLongPress: () =>
                                        onTileLongPress(file.id, key),
                                    onSelect: onTileSelect == null
                                        ? null
                                        : () => onTileSelect!(file.id),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
