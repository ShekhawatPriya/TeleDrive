part of '../account_bottom_sheet.dart';

extension _AccountSheetActions on _AccountBottomSheetState {
  Widget _buildCompactActionPill(
    BuildContext context, {
    required List<_CompactPillAction> actions,
  }) {
    // Segmented group: only the outermost corners of the block are rounded;
    // inner seams stay nearly square so the 2dp gap reads as a hairline.
    const outer = Radius.circular(22);
    const inner = Radius.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: 0.5),
          _buildCompactPillRow(
            context,
            icon: actions[i].icon,
            label: actions[i].label,
            onTap: actions[i].onTap,
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? outer : inner,
              bottom: i == actions.length - 1 ? outer : inner,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactPillRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required BorderRadius borderRadius,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _ProfileSheetSection(
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              // Primary-tinted badge — same language as the settings tiles.
              // Kept to ~half the row height so the label stays dominant.
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,

                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: theme.platform == TargetPlatform.iOS ? 17 : 14.5,
                    height: 1.1,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                size: 20,
              ),
            ],
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
                    color: _profileSectionColor(scheme),
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
                    color: _profileSectionColor(scheme),
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
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Help & Feedback'),
          content: const Text(
            'For feedback or bugs, visit the TeleDrive GitHub repository or contact the DevsDoCode support channel.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(ctx);
                AppConfig.openRepository();
              },
              child: const Text('Visit GitHub'),
            ),
          ],
        ),
      );
      return;
    }
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
