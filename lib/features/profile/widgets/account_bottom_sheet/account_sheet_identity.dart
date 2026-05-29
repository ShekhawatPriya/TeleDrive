part of '../account_bottom_sheet.dart';

extension _AccountSheetIdentity on _AccountBottomSheetState {
  Widget _buildAccountIdentity(
    BuildContext context,
    SavedAccount activeAccount,
    String accountLabel,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left side: Profile picture, username, display name, manage account button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: _buildAvatarWidget(activeAccount, size: 76),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _openTelegramProfile(
                          context,
                          activeAccount.username,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  accountLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Hi, ${activeAccount.displayName}!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTdlibStatusChip(context),
              ],
            ),
          ),
          // Vertical Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: VerticalDivider(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
              thickness: 1,
            ),
          ),
          // Right side: Active ID, Version, GitHub/Open Source Link
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Active ID',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${activeAccount.telegramId}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Version',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ver: ${AppConfig.appVersion}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSocialIconButton(
                        context,
                        icon: GitHubIcon(size: 22, color: scheme.onSurface),
                        onTap: AppConfig.openRepository,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      _buildSocialIconButton(
                        context,
                        icon: InstagramIcon(size: 22, color: scheme.onSurface),
                        onTap: AppConfig.openInstagram,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      _buildSocialIconButton(
                        context,
                        icon: XIcon(size: 22, color: scheme.onSurface),
                        onTap: AppConfig.openTwitter,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      _buildSocialIconButton(
                        context,
                        icon: YouTubeIcon(size: 22, color: scheme.onSurface),
                        onTap: AppConfig.openYouTube,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIconButton(
    BuildContext context, {
    required Widget icon,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: scheme.primary.withValues(alpha: 0.12),
        highlightColor: scheme.primary.withValues(alpha: 0.06),
        child: Padding(padding: const EdgeInsets.all(6.0), child: icon),
      ),
    );
  }

  Widget _buildLegalFooter(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.normal,
      decoration: TextDecoration.none,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => context.safePush('/privacy'),
          child: Text('Privacy Policy', style: style),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('•', style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
        GestureDetector(
          onTap: () => context.safePush('/terms'),
          child: Text('Terms of Service', style: style),
        ),
      ],
    );
  }
}
