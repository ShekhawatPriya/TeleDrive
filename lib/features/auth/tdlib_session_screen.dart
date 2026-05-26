import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../drive/drive_controller.dart';
import '../drive/drive_tab_commands.dart';
import '../profile/storage_summary_controller.dart';
import '../search/search_controller.dart';
import '../share/share_controller.dart';
import '../upload/upload_controller.dart';
import 'auth_controller.dart';
import 'tdlib_auto_authorization_models.dart';
import 'tdlib_session_controller.dart';

part 'tdlib_session_screen_actions.dart';
part 'tdlib_session_screen_controls.dart';
part 'tdlib_session_screen_view.dart';

class TdlibSessionScreen extends ConsumerStatefulWidget {
  const TdlibSessionScreen({
    this.mode,
    this.source,
    this.returnTo,
    this.previousUserId,
    super.key,
  });

  final String? mode;
  final PendingTdlibMode? source;
  final String? returnTo;
  final int? previousUserId;

  @override
  ConsumerState<TdlibSessionScreen> createState() => _TdlibSessionScreenState();
}

class _TdlibSessionScreenState extends ConsumerState<TdlibSessionScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _autoStarted = false;
  bool _submitting = false;
  bool _submittingPassword = false;
  bool _manualCodeVisible = false;
  bool _codeSheetVisible = false;
  bool _codeSheetShown = false;
  bool _navigating = false;
  bool _disposed = false;
  bool _obscurePassword = true;
  int _uiRunId = 0;
  ProviderSubscription<TdlibSessionController>? _tdlibSub;
  TdlibAutoAuthStage? _lastObservedStage;
  TdlibSessionStatus? _lastObservedStatus;
  String? _error;

  void _setUiState(VoidCallback change) => setState(change);

  @override
  void initState() {
    super.initState();
    _tdlibSub = ref.listenManual<TdlibSessionController>(
      tdlibSessionControllerProvider,
      (previous, next) {
        if (!mounted || _disposed) return;
        _onTdlibChanged(previous?.state, next.state);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed || _navigating) return;
      final auth = ref.read(authControllerProvider);
      _phone.text = auth.activeAccount?.phoneNumber ?? '';
      _startAutomation();
      // The provider runs check() eagerly, so the controller may already be
      // ready before this screen attached its listener. Evaluate the current
      // state so navigation still fires in that race.
      final current = ref.read(tdlibSessionControllerProvider).state;
      _onTdlibChanged(null, current);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _uiRunId++;
    _tdlibSub?.close();
    _tdlibSub = null;
    final auth = ref.read(authControllerProvider);
    final candidateTelegramId = auth.pendingCandidateTelegramId;
    if (candidateTelegramId != null) {
      auth.clearEphemeralTelegramCloudPassword(
        telegramUserId: candidateTelegramId,
      );
    } else {
      auth.clearEphemeralTelegramCloudPassword();
    }
    ref.read(tdlibSessionControllerProvider).cancelAutomation();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  PendingTdlibMode get _resolvedSource {
    return widget.source ??
        ref.read(authControllerProvider).pendingTdlibMode ??
        PendingTdlibMode.normalLogin;
  }

  void _onTdlibChanged(TdlibSessionState? previous, TdlibSessionState next) {
    if (_navigating) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated && !auth.loading) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed) context.go('/welcome');
      });
      return;
    }
    // ChangeNotifierProvider hands us the same controller instance as previous
    // and next, so `previous.state` is identical to `next.state` and useless
    // for diffing. Always compare against our own last-observed snapshots.
    final priorStage = _lastObservedStage;
    final priorStatus = _lastObservedStatus;
    _lastObservedStage = next.auto.stage;
    _lastObservedStatus = next.status;
    final stageChanged = priorStage != next.auto.stage;
    final statusChanged = priorStatus != next.status;
    final atFinish =
        next.status == TdlibSessionStatus.ready ||
        next.auto.stage == TdlibAutoAuthStage.authorized;
    final reachedFinish =
        atFinish &&
        (statusChanged ||
            stageChanged ||
            // Initial observation (snapshots were both null): controller may
            // have already settled before the screen attached its listener.
            (priorStage == null && priorStatus == null));
    if (reachedFinish) {
      unawaited(_navigateAfterSuccess());
    }
    if (stageChanged &&
        next.auto.stage != TdlibAutoAuthStage.manualCodeRequired) {
      _codeSheetShown = false;
    }
    if (stageChanged &&
        next.auto.stage == TdlibAutoAuthStage.manualCodeRequired &&
        !_codeSheetShown &&
        !_codeSheetVisible &&
        !_manualCodeVisible) {
      _codeSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed && !_navigating) _showManualCodeSheet();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(tdlibSessionControllerProvider);
    final session = controller.state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _navigating || _disposed) return;
        await _cancelTdlibAuthorization();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cancel setup',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _cancelTdlibAuthorization(),
          ),
          title: Text(_appBarTitle()),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AnimatedSwitcher(
                  duration: AppDurations.medium2,
                  child: _buildAutoCard(session, theme, scheme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
