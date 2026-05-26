part of 'login_screen.dart';

extension _LoginScreenView on _LoginScreenState {
  Widget _buildHeader() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (title, subtitle) = switch (_step) {
      _Step.phone => (
        'Sign in to TeleDrive',
        'Enter your phone number to connect your Telegram account.',
      ),
      _Step.code => (
        'Verification code',
        'We sent a code to your Telegram app. Enter it below.',
      ),
      _Step.password => (
        'Two-factor authentication',
        'Your account has 2FA enabled. Enter your cloud password.',
      ),
    };

    return Column(
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoginStepIndicator(
              currentStep: _step.index,
              totalSteps: _Step.values.length,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null) ...[
              LoginErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_step == _Step.phone) _buildPhoneStep(),
            if (_step == _Step.code) _buildCodeStep(),
            if (_step == _Step.password) _buildPasswordStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _pickCountry,
          borderRadius: AppRadii.xsR,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Country',
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  _selectedCountry.flag,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              suffixIcon: Icon(
                Icons.arrow_drop_down_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ),
            child: Text(
              '${_selectedCountry.name} (${_selectedCountry.dialCode})',
              style: theme.textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.send,
          decoration: InputDecoration(
            labelText: 'Phone number',
            prefixIcon: const Icon(Icons.phone_outlined),
            prefixText: '${_selectedCountry.dialCode} ',
            prefixStyle: theme.textTheme.bodyLarge,
          ),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _loading ? null : _sendCode,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: const InputDecoration(
            labelText: 'Verification code',
            counterText: '',
            hintText: '——————',
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _loading ? null : _verifyCode,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Verify'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: () => _setStep(_Step.phone),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Wrong number?'),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
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
          autofocus: true,
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
          onSubmitted: (_) => _verifyPassword(),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _loading ? null : _verifyPassword,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Sign in'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          onPressed: () => _setStep(_Step.phone),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Start over'),
        ),
      ],
    );
  }
}
