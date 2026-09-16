import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_theme.dart';
import 'app_update_controller.dart';
import 'app_update_models.dart';

part 'app_update_screen_cards.dart';
part 'app_update_screen_hero.dart';
part 'app_update_screen_status_views.dart';

class AppUpdateScreen extends ConsumerStatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  ConsumerState<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends ConsumerState<AppUpdateScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(appUpdateControllerProvider);
      controller.clearManualMessages();
      controller.checkForUpdate(reason: AppUpdateCheckReason.dedicatedScreen);
    });
  }

  Future<void> _recheck() async {
    final controller = ref.read(appUpdateControllerProvider);
    controller.clearManualMessages();
    await controller.checkForUpdate(
      reason: AppUpdateCheckReason.dedicatedScreen,
    );
  }

  Future<void> _download() async {
    final ok = await ref.read(appUpdateControllerProvider).openDownload();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the download link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appUpdateControllerProvider);
    final state = controller.state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final status = _resolveStatus(state);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('App Update'),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(status),
            child: _buildBody(context, status, state),
          ),
        ),
      ),
    );
  }

  _UpdateStatus _resolveStatus(AppUpdateState state) {
    if (state.isChecking) return _UpdateStatus.checking;
    if (state.lastError != null) return _UpdateStatus.error;
    if (state.update != null) return _UpdateStatus.available;
    return _UpdateStatus.upToDate;
  }

  Widget _buildBody(
    BuildContext context,
    _UpdateStatus status,
    AppUpdateState state,
  ) {
    switch (status) {
      case _UpdateStatus.checking:
        return _CheckingView(packageInfo: _packageInfo);
      case _UpdateStatus.upToDate:
        return _UpToDateView(packageInfo: _packageInfo, onRecheck: _recheck);
      case _UpdateStatus.available:
        return _AvailableView(
          info: state.update!,
          onDownload: _download,
          onRecheck: _recheck,
        );
      case _UpdateStatus.error:
        return _ErrorView(
          message: state.lastError ?? 'Something went wrong',
          onRetry: _recheck,
        );
    }
  }
}
