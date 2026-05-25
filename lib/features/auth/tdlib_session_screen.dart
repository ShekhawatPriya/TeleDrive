import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../drive/drive_controller.dart';
import '../drive/drive_tab_commands.dart';
import '../search/search_controller.dart';
import '../share/share_controller.dart';
import '../upload/upload_controller.dart';
import 'auth_controller.dart';
import 'tdlib_auto_authorization_models.dart';
import 'tdlib_session_controller.dart';

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

  Future<void> _startAutomation({
    bool restartOtpWindow = false,
    bool force = false,
  }) async {
    if (_autoStarted && !restartOtpWindow && !force) return;
    final auth = ref.read(authControllerProvider);
    final active = auth.activeAccount;
    final phone =
        auth.pendingCandidatePhone ?? active?.phoneNumber ?? _phone.text;
    final telegramUserId = auth.user?.telegramId != 0
        ? auth.user?.telegramId ?? 0
        : active?.telegramId ?? 0;
    final backendUserId = auth.user?.userId ?? active?.userId ?? 0;
    if (phone.isEmpty || telegramUserId == 0 || backendUserId == 0) {
      if (mounted) {
        setState(() {
          _error = 'Could not confirm your Telegram phone number.';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _autoStarted = true;
        _manualCodeVisible = false;
        _error = null;
      });
    }
    unawaited(
      ref
          .read(tdlibSessionControllerProvider)
          .authorizeAutomatically(
            phoneNumber: phone,
            telegramUserId: telegramUserId,
            backendUserId: backendUserId,
            mode: _resolvedSource,
            restartOtpWindow: restartOtpWindow,
          ),
    );
  }

  Future<void> _retryOtp() async {
    if (mounted) setState(() => _error = null);
    await ref.read(tdlibSessionControllerProvider).retryOtp();
  }

  Future<void> _submitManualAutoCode() async {
    if (_submitting || _code.text.trim().isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(tdlibSessionControllerProvider)
          .submitManualCodeForAutomation(_code.text.trim());
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitManualPassword() async {
    if (_submittingPassword || _password.text.isEmpty) return;
    setState(() {
      _submittingPassword = true;
      _error = null;
    });
    try {
      await ref
          .read(tdlibSessionControllerProvider)
          .submitManualPasswordForAutomation(_password.text);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _submittingPassword = false);
    }
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
    if (stageChanged && next.auto.stage != TdlibAutoAuthStage.manualCodeRequired) {
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

  Future<void> _navigateAfterSuccess() async {
    final run = ++_uiRunId;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || _disposed || run != _uiRunId || _navigating) return;
    _navigating = true;
    final auth = ref.read(authControllerProvider);
    await _resetForCommittedAccount();
    if (!mounted || _disposed) return;
    final destination = auth.commitPendingAccountAuthorization();
    if (!mounted || _disposed) return;
    context.go(destination);
  }

  Future<void> _resetForCommittedAccount() async {
    try {
      final upload = ref.read(uploadControllerProvider);
      if (!upload.hasBlockingUploads) {
        upload.resetTerminalForAccountSwitch();
      }
      await ref.read(driveControllerProvider).resetForAccountSwitch();
      final bootstrap = ref
          .read(authControllerProvider)
          .takePendingDriveBootstrap();
      if (bootstrap != null) {
        ref.read(driveControllerProvider).applyDriveState(bootstrap);
      } else {
        await ref.read(driveControllerProvider).refresh(force: true);
      }
      ref.read(shareControllerProvider).resetForAccountSwitch();
      ref.read(selectionModeStateProvider).setDriveSelectMode(false);
      ref.read(selectionModeStateProvider).setPhotosSelectMode(false);
      for (final scope in SearchScope.values) {
        ref.read(searchQueryProvider(scope)).clear();
      }
    } catch (_) {
      // Reset failure should not block navigation; downstream screens will refresh.
    }
  }

  Future<void> _cancelTdlibAuthorization() async {
    if (_navigating || _disposed) return;
    _navigating = true;
    ref.read(tdlibSessionControllerProvider).cancelAutomation();
    final auth = ref.read(authControllerProvider);
    final destination = await auth.abortPendingTdlibAuthorization();
    if (!mounted || _disposed) return;
    context.go(destination);
  }

  Future<void> _switchToPreviousAccount() async {
    if (_navigating || _disposed) return;
    final auth = ref.read(authControllerProvider);
    final previousUserId =
        widget.previousUserId ?? auth.pendingPreviousUserId;
    if (previousUserId == null) {
      await _cancelTdlibAuthorization();
      return;
    }
    _navigating = true;
    ref.read(tdlibSessionControllerProvider).cancelAutomation();
    final destination = await auth.abortPendingTdlibAuthorization();
    if (!mounted || _disposed) return;
    context.go(destination);
  }

  Future<void> _signOutFromHere() async {
    if (_navigating || _disposed) return;
    _navigating = true;
    ref.read(tdlibSessionControllerProvider).cancelAutomation();
    await ref.read(authControllerProvider).signOutAll();
    if (!mounted || _disposed) return;
    context.go('/welcome');
  }

  Future<void> _showManualCodeSheet() async {
    _codeSheetVisible = true;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Telegram code needed',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'We could not detect the latest Telegram code automatically. You can enter it manually or try automatic detection again.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'manual'),
                  child: const Text('Enter manually'),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'retry'),
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    _codeSheetVisible = false;
    if (!mounted || _disposed) return;
    if (action == 'manual') {
      setState(() => _manualCodeVisible = true);
    } else if (action == 'retry') {
      await _retryOtp();
    }
  }

  String _appBarTitle() {
    return switch (_resolvedSource) {
      PendingTdlibMode.addAccount => 'Add account',
      PendingTdlibMode.reauthenticateAccount => 'Reconnect account',
      PendingTdlibMode.normalLogin => 'Set up account',
    };
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

  Widget _buildAutoCard(
    TdlibSessionState session,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final auto = session.auto;
    final busy = auto.isAutomationActive || _submitting || _submittingPassword;
    final value = auto.progressPercent.clamp(0, 100) / 100;
    final auth = ref.watch(authControllerProvider);
    final hasPreviousAccount =
        (widget.previousUserId ?? auth.pendingPreviousUserId) != null;
    return Card(
      key: const ValueKey('tdlib-auto-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: auto.stage == TdlibAutoAuthStage.authorized
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: AppRadii.mdR,
                ),
                child: Icon(
                  auto.stage == TdlibAutoAuthStage.authorized
                      ? Icons.check_rounded
                      : Icons.phonelink_lock_rounded,
                  color: auto.stage == TdlibAutoAuthStage.authorized
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Authorize TDLib',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Setting up secure local transfer on this device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: AppRadii.xsR,
              child: LinearProgressIndicator(value: value),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    auto.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              auto.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (auto.stage == TdlibAutoAuthStage.waitingForCode &&
                auto.otpSecondsRemaining != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildTimerPill(auto.otpSecondsRemaining!, theme, scheme),
            ],
            const SizedBox(height: AppSpacing.lg),
            _buildProgressSteps(auto.progressPercent, theme, scheme),
            if (auto.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildMessage(
                auto.error!,
                scheme.errorContainer,
                scheme.onErrorContainer,
                theme,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildMessage(
                _error!,
                scheme.errorContainer,
                scheme.onErrorContainer,
                theme,
              ),
            ],
            if (auto.stage == TdlibAutoAuthStage.manualPasswordRequired) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildManualPasswordFallback(theme),
            ] else if (_manualCodeVisible ||
                auto.stage == TdlibAutoAuthStage.manualCodeRequired) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildManualCodeFallback(theme),
            ],
            if (auto.stage == TdlibAutoAuthStage.failed) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => _startAutomation(restartOtpWindow: true),
                child: const Text('Retry'),
              ),
            ],
            if (auto.stage == TdlibAutoAuthStage.idle) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => _startAutomation(force: true),
                child: const Text('Start authorization'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (hasPreviousAccount)
              OutlinedButton.icon(
                onPressed: _navigating ? null : _switchToPreviousAccount,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Back to existing account'),
              )
            else
              TextButton.icon(
                onPressed: _navigating ? null : _signOutFromHere,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerPill(int seconds, ThemeData theme, ColorScheme scheme) {
    final display = '00:${seconds.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadii.smR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            display,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSecondaryContainer,
              fontFamily: 'JetBrains Mono',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps(
    int progress,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    const steps = [
      (18, 'Preparing local TDLib engine'),
      (32, 'Confirming Telegram account'),
      (45, 'Waiting for Telegram verification'),
      (78, 'Securing local session'),
      (92, 'Finalizing transfer channel'),
    ];
    return Column(
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Icon(
                  progress >= step.$1
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: progress >= step.$1
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    step.$2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: progress >= step.$1
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildManualCodeFallback(ThemeData theme) {
    if (!_manualCodeVisible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () => setState(() => _manualCodeVisible = true),
            child: const Text('Enter code manually'),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: _retryOtp,
            child: const Text('Try again'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(
            labelText: 'Telegram code',
            counterText: '',
          ),
          onSubmitted: (_) => _submitManualAutoCode(),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _submitting ? null : _submitManualAutoCode,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Text('Continue'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: _retryOtp,
          child: const Text('Try automatic detection again'),
        ),
      ],
    );
  }

  Widget _buildManualPasswordFallback(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _password,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          enableSuggestions: false,
          autocorrect: false,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Cloud password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: (_) => _submitManualPassword(),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _submittingPassword ? null : _submitManualPassword,
          child: _submittingPassword
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildMessage(
    String text,
    Color background,
    Color foreground,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.smR),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: foreground,
          height: 1.35,
        ),
      ),
    );
  }
}
