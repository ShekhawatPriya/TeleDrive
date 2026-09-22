part of 'login_screen.dart';

extension _LoginScreenActions on _LoginScreenState {
  void _setStep(_Step next) {
    _setUiState(() {
      _step = next;
      _error = null;
      if (next == _Step.phone) {
        _attemptId = null;
        _attemptToken = null;
        _code.clear();
        _password.clear();
        _obscurePassword = true;
      }
    });
    HapticFeedback.lightImpact();
  }

  Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function() fn,
  ) async {
    _setUiState(() {
      _loading = true;
      _error = null;
    });
    try {
      return await fn();
    } catch (err) {
      if (!mounted) rethrow;
      final repo = ref.read(authRepositoryProvider);
      _setUiState(() => _error = repo.api.errorMessage(err));
      rethrow;
    } finally {
      if (mounted) _setUiState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    if (_loading) return;
    final local = _phone.text.replaceAll(RegExp(r'\s+'), '');
    if (local.isEmpty) {
      _setUiState(() => _error = 'Please enter your phone number');
      return;
    }
    try {
      final data = await _call(
        () => ref
            .read(authRepositoryProvider)
            .start('${_selectedCountry.dialCode}$local'),
      );
      if (!mounted) return;
      _attemptId = (data['attempt_id'] as num).toInt();
      _attemptToken = data['attempt_token'] as String;
      _setStep(_Step.code);
    } catch (_) {}
  }

  Future<void> _verifyCode() async {
    if (_loading) return;
    if (_attemptId == null ||
        _attemptToken == null ||
        _code.text.trim().isEmpty) {
      _setUiState(() => _error = 'Please enter the verification code');
      return;
    }
    try {
      final data = await _call(
        () => ref
            .read(authRepositoryProvider)
            .verifyCode(_attemptId!, _attemptToken!, _code.text.trim()),
      );
      if (!mounted) return;
      if (data['status'] == 'requires_2fa') {
        _setStep(_Step.password);
      } else if (data['token'] != null) {
        await _completeLogin('${data['token']}', data);
      }
    } catch (_) {}
  }

  Future<void> _verifyPassword() async {
    if (_loading) return;
    if (_attemptId == null ||
        _attemptToken == null ||
        _password.text.trim().isEmpty) {
      _setUiState(() => _error = 'Please enter your password');
      return;
    }
    try {
      final data = await _call(
        () => ref
            .read(authRepositoryProvider)
            .verifyPassword(_attemptId!, _attemptToken!, _password.text.trim()),
      );
      if (!mounted) return;
      if (data['token'] != null) {
        await _completeLogin(
          '${data['token']}',
          data,
          ephemeralCloudPassword: _password.text.trim(),
        );
      }
    } catch (_) {}
  }

  Future<void> _completeLogin(
    String token,
    Map<String, dynamic> authPayload, {
    String? ephemeralCloudPassword,
  }) async {
    _setUiState(() {
      _loading = true;
      _error = null;
      _attemptId = null;
      _attemptToken = null;
      _code.clear();
      _password.clear();
    });
    try {
      final auth = ref.read(authControllerProvider);
      final pendingMode = switch (widget.mode) {
        LoginMode.normalLogin => PendingTdlibMode.normalLogin,
        LoginMode.addAccount => PendingTdlibMode.addAccount,
        LoginMode.reauthenticateAccount =>
          PendingTdlibMode.reauthenticateAccount,
      };
      final candidatePhone =
          '${_selectedCountry.dialCode}${_phone.text.replaceAll(RegExp(r'\s+'), '')}';
      // Snapshot the previous active account BEFORE login() commits the candidate.
      auth.beginPendingAccountAuthorization(
        mode: pendingMode,
        candidateUserId: 0,
        candidateTelegramId: 0,
        candidatePhone: candidatePhone,
        returnTo: widget.returnTo,
      );
      final previousUserId = auth.pendingPreviousUserId;
      await auth.login(token, authPayload: authPayload);
      final candidateUserId = auth.user?.userId ?? 0;
      final candidateTelegramId = auth.user?.telegramId ?? 0;
      auth.updatePendingAccountCandidate(
        candidateUserId: candidateUserId,
        candidateTelegramId: candidateTelegramId,
      );
      if (ephemeralCloudPassword != null &&
          ephemeralCloudPassword.isNotEmpty &&
          candidateTelegramId != 0) {
        auth.rememberEphemeralTelegramCloudPassword(
          candidateTelegramId,
          ephemeralCloudPassword,
        );
      }
      if (!mounted) return;

      final destination = _tdlibDestination(
        _authenticatedDestination(),
        mode: pendingMode,
        previousUserId: previousUserId,
      );
      context.go(destination);
    } catch (err) {
      final auth = ref.read(authControllerProvider);
      if (auth.pendingCandidateTelegramId != null) {
        auth.clearEphemeralTelegramCloudPassword(
          telegramUserId: auth.pendingCandidateTelegramId,
        );
      } else {
        auth.clearEphemeralTelegramCloudPassword();
      }
      final repo = ref.read(authRepositoryProvider);
      if (mounted) {
        _setUiState(() {
          _step = _Step.phone;
          _error = repo.api.errorMessage(err);
        });
      }
    } finally {
      if (mounted) _setUiState(() => _loading = false);
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(context);
    if (picked != null && mounted) _setUiState(() => _selectedCountry = picked);
  }

  String _authenticatedDestination() {
    final target = widget.returnTo;
    if (target == null || target.isEmpty || target == '/login') return '/drive';
    return target;
  }

  String _tdlibDestination(
    String returnTo, {
    required PendingTdlibMode mode,
    int? previousUserId,
  }) {
    return Uri(
      path: '/tdlib-session',
      queryParameters: {
        'mode': 'auto',
        'source': mode.name,
        if (returnTo != '/tdlib-session') 'returnTo': returnTo,
        if (previousUserId != null) 'previousUserId': '$previousUserId',
      },
    ).toString();
  }

  String _cancelDestination() {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return '/welcome';
    return _authenticatedDestination();
  }
}
