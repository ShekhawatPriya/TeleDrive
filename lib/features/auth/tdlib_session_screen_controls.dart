part of 'tdlib_session_screen.dart';

extension _TdlibSessionScreenControls on _TdlibSessionScreenState {
  Widget _buildProgressSteps(
    int progress,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    const steps = [
      (18, 'Start secure connection'),
      (32, 'Request sign-in code'),
      (45, 'Read code automatically'),
      (78, 'Secure this device'),
      (92, 'Finish setup'),
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
