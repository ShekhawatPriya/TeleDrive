import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import 'folder_toast.dart';
import 'folder_toast_controller.dart';

class FolderToastOverlay extends ConsumerWidget {
  const FolderToastOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(folderToastControllerProvider).value;
    return IgnorePointer(child: FolderToast(state: state));
  }
}

/// Bottom-anchored slot for [FolderToastOverlay]. Reserves space on the right
/// for the 56 dp FAB plus an [AppSpacing.sm] gap so the pill never overlaps
/// it, and matches the FAB's `endFloat` vertical anchor by adding the system
/// bottom view-padding (home indicator etc.) to the bottom offset. Must be a
/// direct child of a [Stack].
class FolderToastSlot extends StatelessWidget {
  const FolderToastSlot({super.key});

  static const double _fabSize = 56;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md + _fabSize + AppSpacing.sm,
      bottom: bottomInset + AppSpacing.md,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: FolderToastOverlay(),
      ),
    );
  }
}
