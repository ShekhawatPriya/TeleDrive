import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../upload_controller.dart';
import '../../../drive/components/delete_progress_pill.dart';
import '../../../drive/components/drive_fab.dart';
import '../../../drive/drive_controller.dart';
import 'upload_collapsed_bar.dart';
import '../upload_sheet.dart';

/// Redesigned unified bottom overlay system.
///
/// Places the [UploadCollapsedBar] and [DriveFab] side-by-side on the same
/// visual plane with consistent spacing, shadow depth, and border radii.
/// Animates dynamically and transitions smoothly across screens.
class BottomActionSystem extends ConsumerWidget {
  const BottomActionSystem({required this.showFab, this.parentId, super.key});

  final bool showFab;
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      uploadControllerProvider.select((c) => c.summary),
    );
    final deleteProgress = ref.watch(
      driveControllerProvider.select((c) => c.state.deleteProgress),
    );
    final showProgress = summary.sheetVisible && summary.itemCount > 0;
    final showDelete = deleteProgress != null;

    if (!showProgress && !showFab && !showDelete) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth - (2 * AppSpacing.md);

    return Hero(
      tag: 'bottom_action_system_hero',
      child: SizedBox(
        width: contentWidth,
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showDelete)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppDurations.medium3,
                    switchInCurve: AppEasing.emphasizedDecelerate,
                    switchOutCurve: AppEasing.emphasizedAccelerate,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: const DeleteProgressPill(
                      key: ValueKey('delete_progress_pill'),
                    ),
                  ),
                ),
              if (showDelete && (showProgress || showFab))
                const SizedBox(width: AppSpacing.sm),
              if (showProgress)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppDurations.medium3,
                    switchInCurve: AppEasing.emphasizedDecelerate,
                    switchOutCurve: AppEasing.emphasizedAccelerate,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: UploadCollapsedBar(
                      key: const ValueKey('upload_progress_collapsed_bar'),
                      summary: summary,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        useRootNavigator: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        showDragHandle: false,
                        barrierColor: Colors.black.withValues(alpha: .35),
                        builder: (_) => const UploadSheet(),
                      ),
                    ),
                  ),
                ),
              if (showProgress && showFab) const SizedBox(width: AppSpacing.sm),
              if (showFab) DriveFab(parentId: parentId),
            ],
          ),
        ),
      ),
    );
  }
}
