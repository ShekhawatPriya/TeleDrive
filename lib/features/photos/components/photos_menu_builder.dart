import 'package:flutter/material.dart';

import '../../../widgets/ios_menu/ios_menu_models.dart';
import '../photos_grid/photo_grid_density.dart';

/// Three-dots overflow sections for the Photos screen. The previous
/// standalone density `IconButton`s have been folded in here so the
/// navbar matches every other main-tab surface.
List<IosMenuSection> buildPhotosMenuSections(
  BuildContext context, {
  required PhotoGridDensity density,
}) {
  // `density.columns` is inverted relative to "size": higher columns mean
  // smaller tiles. We surface the user-facing labels so the menu reads
  // naturally.
  final atSmallest = density.columns >= density.max; // smallest tiles
  final atLargest = density.columns <= density.min;  // largest tiles

  return [
    IosMenuSection([
      IosMenuItem(
        label: 'Smaller tiles',
        trailingIcon: Icons.grid_view_rounded,
        checked: atSmallest,
        onTap: atSmallest ? () {} : density.zoomOut,
      ),
      IosMenuItem(
        label: 'Larger tiles',
        trailingIcon: Icons.grid_on_rounded,
        checked: atLargest,
        onTap: atLargest ? () {} : density.zoomIn,
      ),
    ]),
  ];
}
