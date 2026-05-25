import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'tdlib_auto_authorization_models.dart';
import 'tdlib_session_controller.dart';

class TdlibSessionScreen extends ConsumerStatefulWidget {
  const TdlibSessionScreen({this.mode, this.returnTo, super.key});

  final String? mode;
  final String? returnTo;

  @override
  ConsumerState<TdlibSessionScreen> createState() => _TdlibSessionScreenState();
}

class _TdlibSessionScreenState extends ConsumerState<TdlibSessionScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _autoStarted = false;
  bool _submitting = false;
  bool _manualCodeVisible = false;
  bool _codeSheetVisible = false;
  bool _codeSheetShown = false;
  bool _navigating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      _phone.text = auth.activeAccount?.phoneNumber ?? '';
      _startAutomation();
    });
  }

  @override
  void dispose() {
    ref.read(authControllerProvider).clearEphemeralTelegramCloudPassword();
    ref.read(tdlibSessionControllerProvider).cancelAutomation();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _startAutomation({
    bool restartOtpWindow = false,
    bool force = false,
  }) async {
    if (_autoStarted && !restartOtpWindow && !force) return;
    final auth = ref.read(authControllerProvider);
    final active = auth.activeAccount;
    final phone = active?.phoneNumber ?? '';
    final telegramUserId = auth.user?.telegramId != 0
        ? auth.user?.telegramId ?? 0
        : active?.telegramId ?? 0;
    if (phone.isEmpty || telegramUserId == 0) {
      setState(() {
        _error = 'Could not confirm your Telegram phone number.';
      });
      return;
    }
    setState(() {
      _autoStarted = true;
      _manualCodeVisible = false;
      _error = null;
    });
    final secret = restartOtpWindow
        ? null
        : auth.takeEphemeralTelegramCloudPassword();
    unawaited(
      ref
          .read(tdlibSessionControllerProvider)
          .authorizeAutomatically(
            phoneNumber: phone,
            telegramUserId: telegramUserId,
            ephemeralCloudPassword: secret,
            restartOtpWindow: restartOtpWindow,
          ),
    );
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

  String _destination() {
    final auth = ref.read(authControllerProvider);
    if (auth.needsCommunityOnboarding) return '/community-setup';
    final target = widget.returnTo;
    if (target != null &&
        target.isNotEmpty &&
        target != '/' &&
        target != '/welcome' &&
        target != '/login' &&
        target != '/tdlib-session' &&
        target != '/community-setup') {
      return target;
    }
    return '/drive';
  }

  void _scheduleAutoSideEffects(
    TdlibSessionState session,
    AuthController auth,
  ) {
    final auto = session.auto;
    if (!auth.isAuthenticated && !auth.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return;
    }
    if (auth.isAuthenticated &&
        !auth.loading &&
        _autoStarted &&
        auto.stage == TdlibAutoAuthStage.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startAutomation(force: true));
      });
    }
    if (session.status == TdlibSessionStatus.ready && !_navigating) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (mounted) context.go(_destination());
      });
    }
    if (auto.stage != TdlibAutoAuthStage.manualCodeRequired) {
      _codeSheetShown = false;
    }
    if (auto.stage == TdlibAutoAuthStage.manualCodeRequired &&
        !_codeSheetShown &&
        !_codeSheetVisible &&
        !_manualCodeVisible) {
      _codeSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showManualCodeSheet();
      });
    }
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
    if (!mounted) return;
    if (action == 'manual') {
      setState(() => _manualCodeVisible = true);
    } else if (action == 'retry') {
      await _startAutomation(restartOtpWindow: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(tdlibSessionControllerProvider);
    final session = controller.state;
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    _scheduleAutoSideEffects(session, auth);

    return Scaffold(
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
    );
  }

  Widget _buildAutoCard(
    TdlibSessionState session,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final auto = session.auto;
    final busy = auto.isAutomationActive || _submitting;
    final value = auto.progressPercent.clamp(0, 100) / 100;
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
            if (_manualCodeVisible ||
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
            onPressed: () => _startAutomation(restartOtpWindow: true),
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
          onPressed: () => _startAutomation(restartOtpWindow: true),
          child: const Text('Try automatic detection again'),
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
