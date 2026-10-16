import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/transfer_live_activity_service.dart';
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
  late final ValueNotifier<int> _openRequests;

  @override
  void initState() {
    super.initState();
    _openRequests = ref
        .read(transferLiveActivityServiceProvider)
        .openTransfersRequests;
    _openRequests.addListener(_handleOpenRequest);
  }

  @override
  void dispose() {
    _openRequests.removeListener(_handleOpenRequest);
    super.dispose();
  }

  /// Tapping the upload Live Activity lands on the upload panel (HIG: open
  /// the app at the related details). Hidden tabs and covered routes skip it.
  void _handleOpenRequest() {
    if (!mounted ||
        _panelOpen ||
        !TickerMode.getValuesNotifier(context).value.enabled)
      return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    if (ref.read(uploadControllerProvider).items.isEmpty) return;
    unawaited(_openPanel());
  }

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
                          switchInCurve: AdaptiveEasing.enter(
                            Theme.of(context).platform,
                          ),
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
                          switchInCurve: AdaptiveEasing.enter(
                            Theme.of(context).platform,
                          ),
                          switchOutCurve: AppEasing.emphasizedAccelerate,
                          transitionBuilder: (child, animation) {
                            // iOS: the capsule grows out of the Add button
                            // that started the upload, with a soft spring.
                            if (Theme.of(context).platform ==
                                TargetPlatform.iOS) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  alignment: Alignment.centerRight,
                                  scale: Tween(begin: .55, end: 1.0).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: const IosSpringCurve(damping: .72),
                                      reverseCurve: Curves.easeInCubic,
                                    ),
                                  ),
                                  child: child,
                                ),
                              );
                            }
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
