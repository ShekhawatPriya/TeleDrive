import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/file_type_detector.dart';
import 'free_up_space/free_up_space_controller.dart';

part 'free_up_space/free_up_space_components.dart';
part 'free_up_space/free_up_space_dialog.dart';

class FreeUpSpaceScreen extends ConsumerStatefulWidget {
  const FreeUpSpaceScreen({super.key});

  @override
  ConsumerState<FreeUpSpaceScreen> createState() => _FreeUpSpaceScreenState();
}

class _FreeUpSpaceScreenState extends ConsumerState<FreeUpSpaceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(freeUpSpaceControllerProvider).scan();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(freeUpSpaceControllerProvider, (previous, next) {
      final previousMessage = previous?.state.lastSuccessMessage;
      final message = next.state.lastSuccessMessage;
      if (message != null && message != previousMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
        Future.microtask(next.clearTransientMessages);
      }
    });

    final controller = ref.watch(freeUpSpaceControllerProvider);
    final state = controller.state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Free up space'),
        actions: [
          IconButton(
            tooltip: 'Scan again',
            onPressed: state.scanning || state.deleting
                ? null
                : () => controller.scan(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'About freeing up space',
            onPressed: () => _showFreeUpSpaceInfoDialog(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            _FreeUpHeroCard(state: state),
            const SizedBox(height: AppSpacing.md),
            if (state.permissionDenied)
              _FreeUpMessageCard(
                icon: Icons.photo_library_outlined,
                title: 'Photo access is needed',
                body:
                    'To find backed-up photos and videos on this device, TeleDrive needs access to your photos and videos.',
                actionLabel: 'Allow access',
                onAction: controller.scan,
              )
            else if (state.error != null)
              _FreeUpMessageCard(
                icon: Icons.cloud_off_outlined,
                title: 'Couldn’t verify cloud copies',
                body: state.error!,
                actionLabel: 'Try again',
                onAction: controller.scan,
              )
            else if (!state.scanning && state.eligibleCount == 0)
              _FreeUpMessageCard(
                icon: Icons.check_circle_outline_rounded,
                title: 'You’re all clear',
                body:
                    'No auto-backed-up photos or videos are ready to remove from this device.',
                subtext:
                    'Manual uploads and unverified items are ignored for safety.',
                actionLabel: 'Scan again',
                onAction: controller.scan,
              ),
            if (state.limitedAccess && !state.permissionDenied) ...[
              const SizedBox(height: AppSpacing.md),
              const _FreeUpLimitedAccessCard(),
            ],
            const SizedBox(height: AppSpacing.md),
            _FreeUpBreakdownCard(state: state),
            const SizedBox(height: AppSpacing.md),
            const _FreeUpSafetyCard(),
            const SizedBox(height: AppSpacing.md),
            const _FreeUpExplanationCard(),
          ],
        ),
      ),
      bottomNavigationBar: _FreeUpBottomBar(
        state: state,
        onScan: controller.scan,
        onFree: () => _confirmAndFree(context, controller, state),
      ),
    );
  }

  Future<void> _confirmAndFree(
    BuildContext context,
    FreeUpSpaceController controller,
    FreeUpSpaceState state,
  ) async {
    final confirmed = await showFreeUpSpaceConfirmationSheet(context, state);
    if (confirmed != true) return;
    final summary = await controller.freeUpSpace();
    if (!context.mounted || summary.deleted > 0 || summary.failed > 0) return;
    if (summary.userCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing was deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
