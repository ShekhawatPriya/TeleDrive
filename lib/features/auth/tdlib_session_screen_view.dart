part of 'tdlib_session_screen.dart';

extension _TdlibSessionScreenView on _TdlibSessionScreenState {
  String _appBarTitle() {
    return switch (_resolvedSource) {
      PendingTdlibMode.addAccount => 'Add account',
      PendingTdlibMode.reauthenticateAccount => 'Reconnect account',
      PendingTdlibMode.normalLogin => 'Set up account',
    };
  }

  Widget _buildAutoCard(
    TdlibSessionState session,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final auto = session.auto;
    final busy = auto.isAutomationActive || _submitting || _submittingPassword;
    final value = auto.progressPercent.clamp(0, 100) / 100;
    final auth = ref.watch(authControllerProvider);
    final hasPreviousAccount =
        (widget.previousUserId ?? auth.pendingPreviousUserId) != null;
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
              'Connect your device',
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
            if (auto.stage == TdlibAutoAuthStage.manualPasswordRequired) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildManualPasswordFallback(theme),
            ] else if (_manualCodeVisible ||
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
            const SizedBox(height: AppSpacing.md),
            if (hasPreviousAccount)
              OutlinedButton.icon(
                onPressed: _navigating ? null : _switchToPreviousAccount,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Back to existing account'),
              )
            else
              TextButton.icon(
                onPressed: _navigating ? null : _signOutFromHere,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
          ],
        ),
      ),
    );
  }
}
