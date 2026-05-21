part of '../account_bottom_sheet.dart';

extension _AccountSheetActions on _AccountBottomSheetState {
  Widget _buildCompactActionPill(
    BuildContext context, {
    required List<_CompactPillAction> actions,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: _profileSectionColor(scheme),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          _AccountBottomSheetState._sectionRadius,
        ),
        side: scheme.brightness == Brightness.light
            ? BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.5,
              )
            : BorderSide.none,
      ),
      child: SizedBox(
        height:
            (_AccountBottomSheetState._compactActionRowHeight *
                actions.length) +
            (_AccountBottomSheetState._compactActionDividerHeight *
                (actions.length - 1)),
        child: Column(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              _buildCompactPillRow(
                context,
                icon: actions[i].icon,
                label: actions[i].label,
                onTap: actions[i].onTap,
              ),
              if (i != actions.length - 1) _buildCompactPillDivider(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPillDivider(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _AccountBottomSheetState._compactActionDividerHeight,
      width: double.infinity,
      child: ColoredBox(color: scheme.surface),
    );
  }

  Widget _buildCompactPillRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: _AccountBottomSheetState._compactActionRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Icon(icon, color: scheme.onSurfaceVariant, size: 26),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlappingAvatars(
    BuildContext context,
    List<TelegramAccount> accounts,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < accounts.length.clamp(0, 2); i++)
            Align(
              widthFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.surfaceContainer,
                    width: 1.5,
                  ),
                ),
                child: _buildAvatarCircle(accounts[i], size: 22),
              ),
            ),
          if (accounts.length > 2)
            Align(
              widthFactor: 0.65,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.surfaceContainer,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${accounts.length - 2}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(TelegramAccount account, {required double size}) {
    final scheme = Theme.of(context).colorScheme;
    final initial = account.firstName.isNotEmpty
        ? account.firstName[0].toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: account.isMock
            ? scheme.secondaryContainer
            : scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.bold,
          color: account.isMock
              ? scheme.onSecondaryContainer
              : scheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(TelegramAccount account, {required double size}) {
    if (account.isMock) {
      return _buildAvatarCircle(account, size: size);
    }
    final auth = ref.watch(authControllerProvider);
    return ProfileAvatar(user: auth.user, size: size);
  }

  void _showHelpFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Feedback'),
        content: const Text(
          'TeleDrive is a cloud drive built on top of the Telegram platform.\n\n'
          'For feedback or bugs, please visit our GitHub repository or contact the DevsDoCode support channel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppConfig.openRepository();
            },
            child: const Text('Visit GitHub'),
          ),
        ],
      ),
    );
  }
}
