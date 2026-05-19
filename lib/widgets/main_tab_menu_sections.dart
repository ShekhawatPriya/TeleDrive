import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/drive/view_preferences_controller.dart';
import 'ios_more_menu.dart';

List<IosMenuSection> buildLayoutMenuSection(WidgetRef ref) {
  final prefs = ref.read(viewPreferencesProvider);
  return [
    IosMenuSection([
      IosMenuItem(
        label: 'Icons',
        trailingIcon: Icons.grid_view,
        checked: prefs.layout == LayoutMode.grid,
        onTap: () =>
            ref.read(viewPreferencesProvider).setLayout(LayoutMode.grid),
      ),
      IosMenuItem(
        label: 'List',
        trailingIcon: Icons.view_list,
        checked: prefs.layout == LayoutMode.list,
        onTap: () =>
            ref.read(viewPreferencesProvider).setLayout(LayoutMode.list),
      ),
    ]),
  ];
}

List<IosMenuSection> buildSortMenuSection(WidgetRef ref) {
  final prefs = ref.read(viewPreferencesProvider);
  return [
    IosMenuSection([
      for (final field in SortField.values)
        IosMenuItem(
          label: _sortLabel(field),
          checked: prefs.sort == field,
          subtitle: prefs.sortSubtitle(field),
          onTap: () => ref.read(viewPreferencesProvider).selectSort(field),
        ),
    ]),
  ];
}

String _sortLabel(SortField f) => switch (f) {
  SortField.name => 'Name',
  SortField.kind => 'Kind',
  SortField.date => 'Date',
  SortField.size => 'Size',
};
