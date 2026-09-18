import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/fab_anchor.dart';
import '../../upload_controller.dart';
import '../../../drive/components/delete_progress_pill.dart';
import '../../../drive/components/drive_fab.dart';
import '../../../drive/drive_controller.dart';
import 'upload_collapsed_bar.dart';
import '../upload_panel_host.dart';

/// Keeps status controls beside Add, stacking concurrent operations so their
/// text remains readable on compact screens.
class BottomActionSystem extends ConsumerStatefulWidget {
  const BottomActionSystem({required this.showFab, this.parentId, super.key});

  final bool showFab;
  final String? parentId;

  @override
  ConsumerState<BottomActionSystem> createState() => _BottomActionSystemState();
}

class _BottomActionSystemState extends ConsumerState<BottomActionSystem> {
  bool _panelOpen = false;
  final _fabKey = GlobalKey();

  Future<void> _openPanel() async {
    setState(() => _panelOpen = true);
    await showUploadPanel(context);
    if (mounted) setState(() => _panelOpen = false);
  }

  @override
  Widget build(BuildContext context) =>
      FabAnchorPublisher(fabKey: _fabKey, child: _buildActions(context));

  Widget _buildActions(BuildContext context) {
    if (_panelOpen) return const SizedBox.shrink();
    final showFab = widget.showFab;
    final parentId = widget.parentId;
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
              if (showDelete || showProgress)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDelete)
                        AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : AppDurations.medium3,
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
                      if (showDelete && showProgress)
                        const SizedBox(height: AppSpacing.sm),
                      if (showProgress)
                        AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : AppDurations.medium3,
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
                            key: const ValueKey(
                              'upload_progress_collapsed_bar',
                            ),
                            summary: summary,
                            onTap: _openPanel,
                          ),
                        ),
                    ],
                  ),
                ),
              if ((showProgress || showDelete) && showFab)
                const SizedBox(width: AppSpacing.sm),
              if (showFab) DriveFab(key: _fabKey, parentId: parentId),
            ],
          ),
        ),
      ),
    );
  }
}
