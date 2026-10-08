import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/ios_more_menu.dart';
import '../../../widgets/main_tab_menu_sections.dart';
import '../../search/search_controller.dart';
import '../../share/share_controller.dart';
import '../drive_tab_commands.dart';
import 'drive_menu_builder.dart';

/// Header overflow menus for the Drive, Starred and Shared tabs. The shell
/// and the iOS large-title headers share one definition, resolved afresh on
/// every opening.
List<IosMenuSection> buildBrowseTabMenuSections(
  BuildContext context,
  WidgetRef ref,
  SearchScope scope,
) => switch (scope) {
  SearchScope.drive => buildDriveMenuSections(
    context,
    ref,
    folderId: null,
    includeLayoutSection: true,
    onSelect: () => ref.read(driveTabCommandsProvider).requestSelectMode(),
  ),
  SearchScope.starred => [
    IosMenuSection([
      IosMenuItem(
        label: 'Select',
        leadingIcon: Icons.check_circle_outline,
        onTap: () => ref.read(starredTabCommandsProvider).requestSelectMode(),
      ),
    ]),
    ...buildLayoutMenuSection(ref),
    ...buildSortMenuSection(ref),
  ],
  SearchScope.shared => [
    IosMenuSection([
      IosMenuItem(
        label: 'Refresh',
        leadingIcon: Icons.refresh_rounded,
        onTap: () => ref.read(shareControllerProvider).refresh(silent: true),
      ),
    ]),
    ...buildLayoutMenuSection(ref),
  ],
  SearchScope.photos => const [],
};
