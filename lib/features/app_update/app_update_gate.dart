import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/root_navigator.dart';
import 'app_update_controller.dart';
import 'app_update_models.dart';
import 'app_update_prompt.dart';

class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  int _lastShownToken = 0;
  bool _isPromptVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(appUpdateControllerProvider)
          .checkForUpdate(reason: AppUpdateCheckReason.startup);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appUpdateControllerProvider);
    final state = controller.state;
    final update = state.update;

    if (update != null &&
        state.promptToken != _lastShownToken &&
        !_isPromptVisible) {
      final tokenForThisPrompt = state.promptToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isPromptVisible) return;
        final latestState = ref.read(appUpdateControllerProvider).state;
        if (latestState.promptToken != tokenForThisPrompt) return;
        final latestUpdate = latestState.update;
        if (latestUpdate == null) return;
        _lastShownToken = tokenForThisPrompt;
        _showPrompt(latestUpdate);
      });
    }

    return widget.child;
  }

  Future<void> _showPrompt(AppUpdateInfo info) async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showPrompt(info);
      });
      return;
    }
    if (_isPromptVisible) return;
    _isPromptVisible = true;
    try {
      await showAppUpdatePrompt(navContext, ref, info);
    } finally {
      if (mounted) _isPromptVisible = false;
    }
  }
}
