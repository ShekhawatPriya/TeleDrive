import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/ios_more_menu.dart';
import '../../upload/ui/folder_creation/folder_toast_controller.dart';
import '../../upload/upload_controller.dart';
import '../drive_controller.dart';
import '../view_preferences_controller.dart';
import 'drive_dialogs.dart';

/// Builds the iOS-style three-dot menu sections for both the home and
/// folder screens.  The home screen omits the layout (Icons/List) section
/// because the home screen still exposes a standalone layout toggle in its
/// header; folder screens have no separate toggle, so the section is shown.
List<IosMenuSection> buildDriveMenuSections(
  BuildContext context,
  WidgetRef ref, {
  required String? folderId,
  required VoidCallback onSelect,
  required bool includeLayoutSection,
}) {
  final prefs = ref.read(viewPreferencesProvider);
  return [
    IosMenuSection([
      IosMenuItem(
        label: 'Select',
        trailingIcon: Icons.check_circle_outline,
        onTap: onSelect,
      ),
      IosMenuItem(
        label: 'New Folder',
        trailingIcon: Icons.create_new_folder_outlined,
        onTap: () => _newFolder(context, ref, folderId),
      ),
      IosMenuItem(
        label: 'Scan Documents',
        trailingIcon: Icons.document_scanner_outlined,
        onTap: () =>
            ref.read(uploadControllerProvider).pickPhoto(folderId: folderId),
      ),
    ]),
    if (includeLayoutSection)
      IosMenuSection([
        IosMenuItem(
          label: 'Icons',
          trailingIcon: Icons.grid_view,
          checked: prefs.layout == LayoutMode.grid,
          onTap: () => ref
              .read(viewPreferencesProvider)
              .setLayout(LayoutMode.grid),
        ),
        IosMenuItem(
          label: 'List',
          trailingIcon: Icons.view_list,
          checked: prefs.layout == LayoutMode.list,
          onTap: () => ref
              .read(viewPreferencesProvider)
              .setLayout(LayoutMode.list),
        ),
      ]),
    IosMenuSection([
      for (final field in SortField.values)
        IosMenuItem(
          label: _sortLabel(field),
          checked: prefs.sort == field,
          subtitle: prefs.sortSubtitle(field),
          onTap: () =>
              ref.read(viewPreferencesProvider).selectSort(field),
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

Future<void> _newFolder(
  BuildContext context,
  WidgetRef ref,
  String? parentId,
) async {
  final name = await promptFolderName(context);
  if (name == null || !context.mounted) return;
  final toast = ref.read(folderToastControllerProvider);
  try {
    await runWithFolderToast(
      toast,
      () => ref.read(driveControllerProvider).createFolder(name, parentId),
    );
  } catch (_) {
    // Toast surfaces the failure.
  }
}
