part of 'tdlib_session_screen.dart';

/// iOS device setup, composed like the system's setup assistants: a progress
/// ring and a plain title, the setup steps as one inset group whose current
/// row carries the live status, and the available actions pinned above the
/// home indicator. The steps, thresholds and messages are the controller's.
extension _TdlibSessionScreenIos on _TdlibSessionScreenState {
  static const _steps = [
    (18, 'Prepare Secure Engine'),
    (32, 'Confirm Telegram Account'),
    (45, 'Verify with Telegram'),
    (78, 'Secure Local Session'),
    (92, 'Finish Transfer Setup'),
  ];

  Widget _buildIosBody(TdlibSessionState session) {
    final scheme = Theme.of(context).colorScheme;
    final auto = session.auto;
    final done = auto.stage == TdlibAutoAuthStage.authorized;
    final busy = auto.isAutomationActive || _submitting || _submittingPassword;
    final progress = done ? 100 : auto.progressPercent.clamp(0, 100);
    // A threshold marks where a step begins: the last step reached is the
    // current one, and every step before it is done.
    final reached = _steps.lastIndexWhere((step) => progress >= step.$1);
    final current = done ? -1 : (reached < 0 ? 0 : reached);
    final failed = auto.stage == TdlibAutoAuthStage.failed;
    final manualPassword =
        auto.stage == TdlibAutoAuthStage.manualPasswordRequired;
    final manualCode =
        !manualPassword &&
        (_manualCodeVisible ||
            auto.stage == TdlibAutoAuthStage.manualCodeRequired);
    final errors = [?auto.error, ?_error];

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: _IosSetupRing(
                          progress: progress / 100,
                          done: done,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        header: true,
                        child: Text(
                          done ? 'You’re All Set' : 'Connect This iPhone',
                          textScaler: MediaQuery.textScalerOf(
                            context,
                          ).clamp(maxScaleFactor: 1.35),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'CupertinoSystemDisplay',
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.5,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          done
                              ? 'Your Telegram session is ready on this iPhone.'
                              : 'TeleDrive is creating a secure Telegram session '
                                    'on this iPhone, so your files transfer '
                                    'directly between it and Telegram.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            letterSpacing: -.3,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      IosGroup(
                        bottomSpacing: errors.isEmpty ? 0 : 12,
                        dividerInset: 50,
                        children: [
                          for (var i = 0; i < _steps.length; i++)
                            _IosSetupStep(
                              title: _steps[i].$2,
                              state: done || i < current
                                  ? _StepState.done
                                  : i == current
                                  ? (failed
                                        ? _StepState.failed
                                        : busy
                                        ? _StepState.active
                                        : _StepState.waiting)
                                  : _StepState.pending,
                              detail: i == current ? auto.subtitle : null,
                              trailing:
                                  i == current &&
                                      auto.stage ==
                                          TdlibAutoAuthStage.waitingForCode &&
                                      auto.otpSecondsRemaining != null
                                  ? _countdown(auto.otpSecondsRemaining!)
                                  : null,
                            ),
                        ],
                      ),
                      for (final message in errors)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.38,
                                color: CupertinoColors.systemRed.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (manualCode && _manualCodeVisible) ...[
                        const SizedBox(height: 28),
                        _iosField(
                          controller: _code,
                          placeholder: 'Telegram Code',
                          code: true,
                          onSubmitted: _submitManualAutoCode,
                        ),
                        _iosFootnote(
                          'Find the code in your Telegram app, in the chat '
                          'from Telegram.',
                        ),
                      ],
                      if (manualPassword) ...[
                        const SizedBox(height: 28),
                        _iosField(
                          controller: _password,
                          placeholder: 'Telegram Password',
                          obscure: _obscurePassword,
                          onSubmitted: _submitManualPassword,
                        ),
                        _iosFootnote(
                          'Your Telegram two-step verification password, not '
                          'your iPhone passcode.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _iosActions(
                  auto: auto,
                  manualCode: manualCode,
                  manualPassword: manualPassword,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _iosActions({
    required TdlibAutoAuthorizationState auto,
    required bool manualCode,
    required bool manualPassword,
  }) {
    final auth = ref.watch(authControllerProvider);
    final hasPreviousAccount =
        (widget.previousUserId ?? auth.pendingPreviousUserId) != null;
    final (String, VoidCallback, bool)? primary = manualPassword
        ? ('Continue', _submitManualPassword, _submittingPassword)
        : manualCode && _manualCodeVisible
        ? ('Continue', _submitManualAutoCode, _submitting)
        : manualCode
        ? (
            'Enter Code Manually',
            () => _setUiState(() => _manualCodeVisible = true),
            false,
          )
        : auto.stage == TdlibAutoAuthStage.failed
        ? ('Try Again', () => _startAutomation(restartOtpWindow: true), false)
        : auto.stage == TdlibAutoAuthStage.idle
        ? ('Start Setup', () => _startAutomation(force: true), false)
        : null;
    final (String, VoidCallback)? secondary = manualCode && _manualCodeVisible
        ? ('Try Automatic Detection Again', _retryOtp)
        : manualCode
        ? ('Send Code Again', _retryOtp)
        : null;
    Widget text(String label, VoidCallback? onPressed, {Color? color}) =>
        CupertinoButton(
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(vertical: 10),
          onPressed: onPressed,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, letterSpacing: -.3, color: color),
          ),
        );
    return [
      if (primary != null)
        LoginPrimaryButton(
          label: primary.$1,
          busy: primary.$3,
          onPressed: primary.$2,
        ),
      if (secondary != null) text(secondary.$1, secondary.$2),
      if (hasPreviousAccount)
        text(
          'Back to Previous Account',
          _navigating ? null : _switchToPreviousAccount,
        )
      else
        text(
          'Sign Out',
          _navigating ? null : _signOutFromHere,
          color: CupertinoColors.systemRed.resolveFrom(context),
        ),
    ];
  }

  Widget _countdown(int seconds) => Text(
    '0:${seconds.toString().padLeft(2, '0')}',
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _iosField({
    required TextEditingController controller,
    required String placeholder,
    required VoidCallback onSubmitted,
    bool code = false,
    bool? obscure,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(IosPageMetrics.groupRadius),
      child: CupertinoTextField(
        controller: controller,
        autofocus: true,
        placeholder: placeholder,
        obscureText: obscure ?? false,
        keyboardType: code
            ? TextInputType.number
            : TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        textAlign: code ? TextAlign.center : TextAlign.start,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: code
            ? const [AutofillHints.oneTimeCode]
            : const [AutofillHints.password],
        inputFormatters: code
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ]
            : null,
        onSubmitted: (_) => onSubmitted(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        style: TextStyle(
          fontSize: code ? 26 : 17,
          letterSpacing: code ? 8 : -.4,
          fontWeight: code ? FontWeight.w500 : FontWeight.w400,
          color: scheme.onSurface,
        ),
        placeholderStyle: TextStyle(
          fontSize: code ? 22 : 17,
          letterSpacing: -.4,
          color: CupertinoColors.placeholderText.resolveFrom(context),
        ),
        suffix: obscure == null
            ? null
            : CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(44, 44),
                onPressed: () =>
                    _setUiState(() => _obscurePassword = !_obscurePassword),
                child: Icon(
                  obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  size: 20,
                  semanticLabel: obscure ? 'Show password' : 'Hide password',
                  color: scheme.onSurfaceVariant,
                ),
              ),
        decoration: BoxDecoration(color: scheme.surfaceContainerLow),
      ),
    );
  }

  Widget _iosFootnote(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.38,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Future<String?> _showIosCodeActionSheet() => showCupertinoModalPopup<String>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: const Text('Telegram Code Needed'),
      message: const Text(
        'The latest Telegram code could not be read automatically. Enter it '
        'yourself, or try automatic detection again.',
      ),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, 'manual'),
          child: const Text('Enter Code Manually'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, 'retry'),
          child: const Text('Try Again'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context, 'cancel'),
        child: const Text('Cancel'),
      ),
    ),
  );
}

enum _StepState { done, active, waiting, failed, pending }

class _IosSetupStep extends StatelessWidget {
  const _IosSetupStep({
    required this.title,
    required this.state,
    this.detail,
    this.trailing,
  });
  final String title;
  final _StepState state;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = state == _StepState.pending;
    final status = switch (state) {
      _StepState.done => Icon(
        CupertinoIcons.checkmark_circle_fill,
        size: 22,
        color: CupertinoColors.systemGreen.resolveFrom(context),
      ),
      _StepState.active => const CupertinoActivityIndicator(radius: 9),
      _StepState.waiting => Icon(
        CupertinoIcons.clock_fill,
        size: 21,
        color: CupertinoColors.systemOrange.resolveFrom(context),
      ),
      _StepState.failed => Icon(
        CupertinoIcons.exclamationmark_circle_fill,
        size: 22,
        color: CupertinoColors.systemRed.resolveFrom(context),
      ),
      _StepState.pending => Icon(
        CupertinoIcons.circle,
        size: 22,
        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
      ),
    };
    return Semantics(
      label:
          '$title, ${switch (state) {
            _StepState.done => 'done',
            _StepState.active => 'in progress',
            _StepState.waiting => 'waiting',
            _StepState.failed => 'failed',
            _StepState.pending => 'not started',
          }}',
      excludeSemantics: detail == null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: IosPageMetrics.rowMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
          child: Row(
            crossAxisAlignment: detail == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              SizedBox(width: 24, child: Center(child: status)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        letterSpacing: -.4,
                        fontWeight:
                            state == _StepState.active ||
                                state == _StepState.waiting ||
                                state == _StepState.failed
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: pending
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    if (detail != null && detail!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A progress ring in the system blue around the setup symbol; it turns into
/// a green check once setup finishes.
class _IosSetupRing extends StatelessWidget {
  const _IosSetupRing({required this.progress, required this.done});
  final double progress;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.systemBlue.resolveFrom(context);
    final green = CupertinoColors.systemGreen.resolveFrom(context);
    final track = CupertinoColors.systemFill.resolveFrom(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: done
          ? 'Setup complete'
          : 'Setup ${(progress * 100).round()} percent complete',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: instant ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(
            value: value,
            color: done ? green : blue,
            track: track,
          ),
          child: SizedBox.square(
            dimension: 96,
            child: Icon(
              done
                  ? CupertinoIcons.checkmark_alt
                  : CupertinoIcons.lock_shield_fill,
              size: done ? 44 : 40,
              color: done ? green : blue,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
  });
  final double value;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.2832, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -1.5708,
        6.2832 * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
