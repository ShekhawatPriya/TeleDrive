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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++)
              _buildCompactPillRow(
                context,
                icon: actions[i].icon,
                label: actions[i].label,
                onTap: actions[i].onTap,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPillRow(
    BuildContext context, {
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final iconBackground = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: _AccountBottomSheetState._compactActionRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: icon,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 15.5,
                      height: 1.1,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  size: 22,
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
    List<SavedAccount> accounts,
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
                child: _buildAvatarWidget(accounts[i], size: 22),
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

  Widget _buildAvatarWidget(SavedAccount account, {required double size}) {
    return ProfileAvatar(
      key: ValueKey(
        'account-avatar-${account.userId}-${account.resolvedPhotoUrl ?? 'fallback'}',
      ),
      user: account.toAuthUser(),
      size: size,
    );
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
