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
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildTdlibStatusChip(context),
            if (!accountLabel.startsWith('ID '))
              Text(
                'ID: ${activeAccount.telegramId}',
                style: theme.textTheme.bodySmall,
              ),
          ],
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
