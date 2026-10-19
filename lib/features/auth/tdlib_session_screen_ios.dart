part of 'tdlib_session_screen.dart';

/// iOS device setup, composed like the system's setup assistants: a progress
/// ring and a plain title, the setup steps as one inset group whose current
/// row carries the live status, and the available actions pinned above the
/// home indicator. The steps, thresholds and messages are the controller's.
///
/// Setup is automatic: TeleDrive reads the Telegram code itself, so the page
/// never offers to type it. The only input it asks for is a two-step
/// verification password TeleDrive does not already have, and the only way
/// to get another code is an explicit Send a New Code.
extension _TdlibSessionScreenIos on _TdlibSessionScreenState {
  static const _steps = [
    (18, 'Start Secure Connection'),
    (32, 'Request Sign-In Code'),
    (45, 'Read Code Automatically'),
    (78, 'Secure This iPhone'),
    (92, 'Finish Setup'),
  ];

  Widget _buildIosBody(TdlibSessionState session) {
    final scheme = Theme.of(context).colorScheme;
    final auto = session.auto;
    final done = auto.stage == TdlibAutoAuthStage.authorized;
    // Before the automation reports its first stage the page is starting,
    // not waiting on the user.
    final starting = auto.stage == TdlibAutoAuthStage.idle && _error == null;
    final busy =
        auto.isAutomationActive ||
        starting ||
        _requestingCode ||
        _submittingPassword;
    final progress = done ? 100 : auto.progressPercent.clamp(0, 100);
    // A threshold marks where a step begins: the last step reached is the
    // current one, and every step before it is done.
    final reached = _steps.lastIndexWhere((step) => progress >= step.$1);
    final current = done ? -1 : (reached < 0 ? 0 : reached);
    final failed = auto.stage == TdlibAutoAuthStage.failed;
    final manualPassword =
        auto.stage == TdlibAutoAuthStage.manualPasswordRequired;
    final needsNewCode = auto.stage == TdlibAutoAuthStage.manualCodeRequired;
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
                              : 'This happens automatically. Telegram sends a '
                                    'code to your Telegram app and TeleDrive '
                                    'reads it for you, so there’s nothing to '
                                    'type.',
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
                  needsNewCode: needsNewCode,
                  manualPassword: manualPassword,
                  busy: busy && !done,
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
    required bool needsNewCode,
    required bool manualPassword,
    required bool busy,
  }) {
    final auth = ref.watch(authControllerProvider);
    final hasPreviousAccount =
        (widget.previousUserId ?? auth.pendingPreviousUserId) != null;
    final (String, VoidCallback, bool)? primary = manualPassword
        ? ('Continue', _submitManualPassword, _submittingPassword)
        : needsNewCode
        ? ('Send a New Code', _requestNewCode, _requestingCode)
        : auto.stage == TdlibAutoAuthStage.failed
        ? ('Try Again', () => _startAutomation(restartOtpWindow: true), false)
        : auto.stage == TdlibAutoAuthStage.idle && _error != null
        ? ('Try Again', () => _startAutomation(force: true), false)
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
        )
      else if (busy)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            'Keep TeleDrive open. This usually takes less than a minute.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.38,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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

  Widget _iosField({
    required TextEditingController controller,
    required String placeholder,
    required VoidCallback onSubmitted,
    required bool obscure,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(IosPageMetrics.groupRadius),
      child: CupertinoTextField(
        controller: controller,
        autofocus: true,
        placeholder: placeholder,
        obscureText: obscure,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) => onSubmitted(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        style: TextStyle(
          fontSize: 17,
          letterSpacing: -.4,
          color: scheme.onSurface,
        ),
        placeholderStyle: TextStyle(
          fontSize: 17,
          letterSpacing: -.4,
          color: CupertinoColors.placeholderText.resolveFrom(context),
        ),
        suffix: CupertinoButton(
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
}

enum _StepState { done, active, waiting, failed, pending }

class _IosSetupStep extends StatelessWidget {
  const _IosSetupStep({required this.title, required this.state, this.detail});
  final String title;
  final _StepState state;
  final String? detail;

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
