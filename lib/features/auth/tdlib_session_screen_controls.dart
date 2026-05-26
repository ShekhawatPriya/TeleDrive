part of 'tdlib_session_screen.dart';

extension _TdlibSessionScreenControls on _TdlibSessionScreenState {
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
            onPressed: () => _setUiState(() => _manualCodeVisible = true),
            child: const Text('Enter code manually'),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(onPressed: _retryOtp, child: const Text('Try again')),
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
                  _setUiState(() => _obscurePassword = !_obscurePassword),
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
