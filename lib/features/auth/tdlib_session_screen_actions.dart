part of 'tdlib_session_screen.dart';

extension _TdlibSessionScreenActions on _TdlibSessionScreenState {
  Future<void> _startAutomation({
    bool restartOtpWindow = false,
    bool force = false,
  }) async {
    if (_autoStarted && !restartOtpWindow && !force) return;
    final auth = ref.read(authControllerProvider);
    // On a cold start that lands directly on this screen the session restore
    // is still in flight; wait for it instead of racing ahead with a null
    // user/account and dead-ending the automation.
    var waitedMs = 0;
    while (auth.loading && waitedMs < 15000) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      waitedMs += 100;
      if (!mounted || _disposed || _navigating) return;
    }
    final active = auth.activeAccount;
    final phone =
        auth.pendingCandidatePhone ?? active?.phoneNumber ?? _phone.text;
    final userTelegramId = auth.user?.telegramId ?? 0;
    final telegramUserId = userTelegramId != 0
        ? userTelegramId
        : active?.telegramId ?? 0;
    final backendUserId = auth.user?.userId ?? active?.userId ?? 0;
    if (phone.isEmpty || telegramUserId == 0 || backendUserId == 0) {
      if (mounted) {
        _setUiState(() {
          _error = 'Could not confirm your Telegram phone number.';
        });
      }
      return;
    }
    if (mounted) {
      _setUiState(() {
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
    if (mounted) _setUiState(() => _error = null);
    await ref.read(tdlibSessionControllerProvider).retryOtp();
  }

  Future<void> _submitManualAutoCode() async {
    if (_submitting || _code.text.trim().isEmpty) return;
    _setUiState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(tdlibSessionControllerProvider)
          .submitManualCodeForAutomation(_code.text.trim());
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) _setUiState(() => _submitting = false);
    }
  }

  Future<void> _submitManualPassword() async {
    if (_submittingPassword || _password.text.isEmpty) return;
    _setUiState(() {
      _submittingPassword = true;
      _error = null;
    });
    try {
      await ref
          .read(tdlibSessionControllerProvider)
          .submitManualPasswordForAutomation(_password.text);
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) _setUiState(() => _submittingPassword = false);
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
      ref.read(storageSummaryControllerProvider).resetForAccountSwitch();
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
    final previousUserId = widget.previousUserId ?? auth.pendingPreviousUserId;
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
      _setUiState(() => _manualCodeVisible = true);
    } else if (action == 'retry') {
      await _retryOtp();
    }
  }
}
