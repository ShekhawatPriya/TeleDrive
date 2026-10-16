part of 'login_screen.dart';

/// iOS sign-in, composed like the system's own account flows: the glass Back,
/// then a solid symbol tile, a plain title and one line of explanation at the
/// top of the page, the fields as one inset group with a footnote, and the
/// primary action pinned above the keyboard or home indicator.
extension _LoginScreenIos on _LoginScreenState {
  Widget _buildIos() {
    final scheme = Theme.of(context).colorScheme;
    final (symbol, title) = switch (_step) {
      _Step.phone => (
        CupertinoIcons.paperplane_fill,
        _reauthAccount == null ? 'Your Phone Number' : 'Sign In Again',
      ),
      _Step.code => (CupertinoIcons.chat_bubble_text_fill, 'Enter Code'),
      _Step.password => (
        CupertinoIcons.lock_shield_fill,
        'Two-Step Verification',
      ),
    };
    final detail = switch (_step) {
      _Step.phone when _reauthAccount != null =>
        'The session for ${_reauthAccount!.displayName} on this iPhone has '
            'ended. Confirm the number to continue where you left off.',
      _Step.phone => 'Sign in with the number you use for Telegram.',
      _Step.code =>
        'Telegram sent a code to ${_selectedCountry.dialCode} '
            '${_phone.text.trim()}. Open Telegram to find it.',
      _Step.password =>
        'This account is protected by a Telegram password. It is not your '
            'iPhone passcode.',
    };
    final footnote = switch (_step) {
      _Step.phone =>
        'We’ll send a sign-in code to your Telegram app. Your files stay in '
            'your Telegram storage.',
      _Step.code => 'Keep Telegram open until you finish signing in.',
      _Step.password => null,
    };
    final (label, action) = switch (_step) {
      _Step.phone => ('Continue', _sendCode),
      _Step.code => ('Verify', _verifyCode),
      _Step.password => ('Sign In', _verifyPassword),
    };
    final secondary = switch (_step) {
      _Step.phone => null,
      _Step.code => ('Use a Different Number', () => _setStep(_Step.phone)),
      _Step.password => ('Start Over', () => _setStep(_Step.phone)),
    };

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SizedBox(
                height: IosPageMetrics.barHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: NativeGlassButton(
                    label: 'Back',
                    symbol: 'chevron.left',
                    icon: CupertinoIcons.chevron_back,
                    size: 44,
                    symbolSize: 18,
                    onPressed: _loading ? null : _back,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      child: Column(
                        key: ValueKey(_step),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: _IosSymbolTile(icon: symbol)),
                          const SizedBox(height: 20),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              detail,
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
                          if (_error != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: _IosErrorNote(message: _error!),
                            ),
                            const SizedBox(height: 12),
                          ],
                          AutofillGroup(child: _buildIosFields()),
                          if (footnote != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Text(
                                footnote,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.38,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LoginPrimaryButton(
                      label: label,
                      busy: _loading,
                      onPressed: action,
                    ),
                    if (secondary != null)
                      CupertinoButton(
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        onPressed: _loading ? null : secondary.$2,
                        child: Text(
                          secondary.$1,
                          style: const TextStyle(
                            fontSize: 16,
                            letterSpacing: -.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIosFields() {
    final scheme = Theme.of(context).colorScheme;
    Widget group(List<Widget> children) => ClipRSuperellipse(
      borderRadius: BorderRadius.circular(IosPageMetrics.groupRadius),
      child: ColoredBox(
        color: scheme.surfaceContainerLow,
        child: Column(children: children),
      ),
    );
    return switch (_step) {
      _Step.phone => group([
        Semantics(
          label: 'Country, ${_selectedCountry.name}',
          button: true,
          excludeSemantics: true,
          child: CupertinoButton(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            onPressed: _loading ? null : _pickCountry,
            child: Row(
              children: [
                Text(
                  _selectedCountry.flag,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCountry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      letterSpacing: -.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 15,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: SizedBox(
            width: double.infinity,
            height: 1 / MediaQuery.devicePixelRatioOf(context),
            child: ColoredBox(color: scheme.outlineVariant),
          ),
        ),
        LoginTextField(
          controller: _phone,
          label: 'Phone number',
          keyboardType: TextInputType.phone,
          action: TextInputAction.send,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          prefix: _selectedCountry.dialCode,
          enabled: !_loading,
          grouped: true,
          onSubmitted: (_) => _sendCode(),
        ),
      ]),
      _Step.code => group([
        LoginTextField(
          controller: _code,
          label: 'Verification code',
          code: true,
          keyboardType: TextInputType.number,
          action: TextInputAction.done,
          autofocus: true,
          autofillHints: const [AutofillHints.oneTimeCode],
          enabled: !_loading,
          grouped: true,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => _verifyCode(),
        ),
      ]),
      _Step.password => group([
        LoginTextField(
          controller: _password,
          label: 'Telegram password',
          keyboardType: TextInputType.visiblePassword,
          action: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          enabled: !_loading,
          obscure: _obscurePassword,
          autofocus: true,
          grouped: true,
          suffix: CupertinoButton(
            key: const ValueKey('toggle-password-visibility'),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(44, 44),
            onPressed: () =>
                _setUiState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              size: 20,
              semanticLabel: _obscurePassword
                  ? 'Show password'
                  : 'Hide password',
              color: scheme.onSurfaceVariant,
            ),
          ),
          onSubmitted: (_) => _verifyPassword(),
        ),
      ]),
    };
  }
}

/// The 64-point solid symbol tile used by the app's hero cards.
class _IosSymbolTile extends StatelessWidget {
  const _IosSymbolTile({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: CupertinoColors.systemBlue.resolveFrom(context),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: SizedBox.square(
        dimension: 64,
        child: Icon(icon, size: 32, color: Colors.white),
      ),
    ),
  );
}

/// An inline error in the system red, without a filled banner.
class _IosErrorNote extends StatelessWidget {
  const _IosErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final red = CupertinoColors.systemRed.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              size: 17,
              color: red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 15, height: 1.35, color: red),
            ),
          ),
        ],
      ),
    );
  }
}
