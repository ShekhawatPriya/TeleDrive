part of '../account_bottom_sheet.dart';

extension _AccountSheetIdentity on _AccountBottomSheetState {
  Widget _buildAccountIdentity(
    BuildContext context,
    SavedAccount activeAccount,
    String accountLabel,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              label: 'Open Telegram profile',
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(36),
                onTap: () =>
                    _openTelegramProfile(context, activeAccount.username),
                child: _buildAvatarWidget(activeAccount, size: 68),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeAccount.displayName,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(accountLabel, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildAccountConnectionDetails(context, activeAccount),
      ],
    );
  }

  Widget _buildAccountConnectionDetails(
    BuildContext context,
    SavedAccount account,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    final connected = ref.watch(authControllerProvider).telegramConnected;
    final label = connected == true
        ? 'Telegram connected'
        : connected == false
        ? 'Reconnect Telegram'
        : 'Connecting…';
    final status = Row(
      children: [
        Icon(
          connected == true
              ? (ios
                    ? CupertinoIcons.checkmark_circle_fill
                    : Icons.check_circle_outline)
              : connected == false
              ? (ios
                    ? CupertinoIcons.exclamationmark_circle
                    : Icons.error_outline)
              : (ios ? CupertinoIcons.clock : Icons.schedule),
          size: 20,
          color: connected == true
              ? AppColors.success
              : connected == false
              ? scheme.error
              : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          ios ? CupertinoIcons.info_circle : Icons.info_outline,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
    void onTap() => ios
        ? _showIosConnectionInfo(context, connected)
        : _showTdlibInfoDialog(context, connected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: scheme.outlineVariant),
        if (ios)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(44, 44),
            onPressed: onTap,
            child: status,
          )
        else
          InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: status,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Telegram ID',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SelectableText(
                '${account.telegramId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountFooter(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(
          'TeleDrive ${AppConfig.appVersion}',
          style: theme.textTheme.bodySmall,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSocialIconButton(
              context,
              label: 'GitHub',
              icon: GitHubIcon(size: 20, color: scheme.onSurface),
              onTap: AppConfig.openRepository,
            ),
            _buildSocialIconButton(
              context,
              label: 'Instagram',
              icon: InstagramIcon(size: 20, color: scheme.onSurface),
              onTap: AppConfig.openInstagram,
            ),
            _buildSocialIconButton(
              context,
              label: 'X',
              icon: XIcon(size: 20, color: scheme.onSurface),
              onTap: AppConfig.openTwitter,
            ),
            _buildSocialIconButton(
              context,
              label: 'YouTube',
              icon: YouTubeIcon(size: 20, color: scheme.onSurface),
              onTap: AppConfig.openYouTube,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialIconButton(
    BuildContext context, {
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: icon,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
  );
}
