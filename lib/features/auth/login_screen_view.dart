part of 'login_screen.dart';

extension _LoginScreenView on _LoginScreenState {
  Widget _buildHeader() {
    final theme = Theme.of(context);
    final (eyebrow, title, detail) = switch (_step) {
      _Step.phone => (
        'CONNECT YOUR ACCOUNT',
        'Your Telegram.\nYour personal drive.',
        'Sign in to bring your files, photos and folders together.',
      ),
      _Step.code => (
        'VERIFY YOUR NUMBER',
        'Check your\nTelegram.',
        'Enter the code sent to ${_selectedCountry.dialCode} ${_phone.text.trim()} in Telegram.',
      ),
      _Step.password => (
        'ONE MORE STEP',
        'Two-step\nverification.',
        'Enter your Telegram two-step verification password to continue.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 35,
              height: 1.13,
              letterSpacing: -1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          detail,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() => AutofillGroup(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Semantics(
            liveRegion: true,
            child: LoginErrorBanner(message: _error!),
          ),
          const SizedBox(height: 16),
        ],
        if (_step == _Step.phone) _buildPhoneStep(),
        if (_step == _Step.code) _buildCodeStep(),
        if (_step == _Step.password) _buildPasswordStep(),
      ],
    ),
  );

  Widget _buildPhoneStep() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final country = Row(
      children: [
        Container(
          width: 32,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _selectedCountry.flag,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _selectedCountry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Icon(
          ios
              ? CupertinoIcons.chevron_up_chevron_down
              : Icons.unfold_more_rounded,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
    final countryControl = Semantics(
      label: 'Choose country',
      button: true,
      child: ios
          ? CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              onPressed: _loading ? null : _pickCountry,
              child: country,
            )
          : InkWell(
              onTap: _loading ? null : _pickCountry,
              borderRadius: BorderRadius.circular(18),
              child: Padding(padding: const EdgeInsets.all(18), child: country),
            ),
    );
    final phone = LoginTextField(
      controller: _phone,
      label: 'Phone number',
      keyboardType: TextInputType.phone,
      action: TextInputAction.send,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      prefix: _selectedCountry.dialCode,
      enabled: !_loading,
      onSubmitted: (_) => _sendCode(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ios)
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: scheme.surfaceContainerLow,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: Column(
              children: [
                countryControl,
                Divider(
                  height: .5,
                  thickness: .5,
                  indent: 18,
                  color: scheme.outlineVariant.withValues(alpha: .6),
                ),
                phone,
              ],
            ),
          )
        else ...[
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            child: countryControl,
          ),
          const SizedBox(height: 16),
          phone,
        ],
        const SizedBox(height: 12),
        Text(
          'We’ll send a sign-in code to Telegram.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        LoginPrimaryButton(
          label: 'Continue',
          busy: _loading,
          onPressed: _sendCode,
        ),
      ],
    );
  }

  Widget _buildCodeStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LoginTextField(
        controller: _code,
        label: 'Verification code',
        code: true,
        keyboardType: TextInputType.number,
        action: TextInputAction.done,
        autofocus: true,
        autofillHints: const [AutofillHints.oneTimeCode],
        enabled: !_loading,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onSubmitted: (_) => _verifyCode(),
      ),
      const SizedBox(height: 24),
      LoginPrimaryButton(
        label: 'Verify',
        busy: _loading,
        onPressed: _verifyCode,
      ),
      const SizedBox(height: 8),
      _secondaryAction('Use a different number', () => _setStep(_Step.phone)),
    ],
  );

  Widget _buildPasswordStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LoginTextField(
        controller: _password,
        label: 'Cloud password',
        keyboardType: TextInputType.visiblePassword,
        action: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        enabled: !_loading,
        obscure: _obscurePassword,
        autofocus: true,
        suffix: IconButton(
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            size: 21,
          ),
          onPressed: () =>
              _setUiState(() => _obscurePassword = !_obscurePassword),
        ),
        onSubmitted: (_) => _verifyPassword(),
      ),
      const SizedBox(height: 24),
      LoginPrimaryButton(
        label: 'Sign in',
        busy: _loading,
        onPressed: _verifyPassword,
      ),
      const SizedBox(height: 8),
      _secondaryAction('Start over', () => _setStep(_Step.phone)),
    ],
  );

  Widget _secondaryAction(String label, VoidCallback onPressed) =>
      Theme.of(context).platform == TargetPlatform.iOS
      ? CupertinoButton(
          onPressed: _loading ? null : onPressed,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        )
      : TextButton(onPressed: _loading ? null : onPressed, child: Text(label));
}
