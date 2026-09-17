import 'package:flutter/material.dart';

import 'photo_date_grouping.dart';
import 'photo_tile.dart';

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
        final count = (constraints.crossAxisExtent / (390 / columns))
            .round()
            .clamp(2, 12);
        final spacing = count >= 4 ? 4.0 : 8.0;
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
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                ),
                itemCount: section.files.length,
                itemBuilder: (_, i) {
                  final file = section.files[i];
                  final key = tileKeys.putIfAbsent(file.id, () => GlobalKey());
                  return PhotoTile(
                    key: key,
                    file: file,
                    selectMode: selectMode,
                    selected: selectedIds.contains(file.id),
                    onTap: () => onTileTap(file.id),
                    onLongPress: () => onTileLongPress(file.id, key),
                    onSelect: onTileSelect == null
                        ? null
                        : () => onTileSelect!(file.id),
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
