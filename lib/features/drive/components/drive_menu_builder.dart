import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/ios_more_menu.dart';
import '../../../widgets/main_tab_menu_sections.dart';

import '../../upload/upload_controller.dart';
import '../drive_controller.dart';
import 'drive_dialogs.dart';

/// Builds the iOS-style three-dot menu sections for both the home and
/// folder screens. Both surface the layout (Icons/List) section here —
/// neither header exposes a standalone layout toggle anymore.
List<IosMenuSection> buildDriveMenuSections(
  BuildContext context,
  WidgetRef ref, {
  required String? folderId,
  required VoidCallback onSelect,
  required bool includeLayoutSection,
}) {
  return [
    IosMenuSection([
      IosMenuItem(
        label: 'Select',
        leadingIcon: Icons.check_circle_outline,
        onTap: onSelect,
      ),
      IosMenuItem(
        label: 'New Folder',
        leadingIcon: Icons.create_new_folder_outlined,
        onTap: () => _newFolder(context, ref, folderId),
      ),
      IosMenuItem(
        label: 'Scan Documents',
        leadingIcon: Icons.document_scanner_outlined,
        onTap: () => ref
            .read(uploadControllerProvider)
            .pickPhoto(folderId: folderId, context: context),
      ),
    ]),
    if (includeLayoutSection) ...buildLayoutMenuSection(ref),
    ...buildSortMenuSection(ref),
  ];
}

Future<void> _newFolder(
  BuildContext context,
  WidgetRef ref,
  String? parentId,
) async {
  final name = await promptFolderName(context);
  if (name == null || !context.mounted) return;
  try {
    await ref.read(driveControllerProvider).createFolder(name, parentId);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create folder. Please try again.'),
        ),
      );
    }
  }
}
