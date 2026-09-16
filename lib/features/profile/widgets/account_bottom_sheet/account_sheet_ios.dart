part of '../account_bottom_sheet.dart';

extension _IosAccountSheet on _AccountBottomSheetState {
  Widget _buildIosAccount(
    BuildContext context,
    SavedAccount? account,
    String label,
    List<SavedAccount> others,
    StorageSummary summary,
    bool backupOn,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = ref.watch(authControllerProvider).telegramConnected;
    return IosPage(
      title: 'Account',
      modal: true,
      controller: widget.scrollController,
      children: [
        if (account != null) ...[
          Center(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openTelegramProfile(context, account.username),
              child: _buildAvatarWidget(account, size: 80),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            account.displayName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Telegram ID ${account.telegramId}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Center(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onPressed: () => _showIosConnectionInfo(context, connected),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connected == true
                        ? CupertinoIcons.checkmark_seal_fill
                        : CupertinoIcons.exclamationmark_circle,
                    size: 15,
                    color: connected == true
                        ? CupertinoColors.systemGreen
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      connected == true
                          ? 'Telegram connected'
                          : connected == false
                          ? 'Reconnect Telegram'
                          : 'Connecting…',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          IosGroup(
            children: [
              IosRow(
                title: 'Switch Account',
                icon: CupertinoIcons.person_2_fill,
                color: CupertinoColors.systemGrey,
                trailing: Icon(
                  _isExpanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                ),
                onTap: () {
                  if (!_isExpanded &&
                      ref
                          .read(switchAccountProvider.notifier)
                          .checkUploadsBlocked(context))
                    return;
                  _toggleSwitchAccountCard();
                },
              ),
              if (_isExpanded) ...[
                for (final saved in [account, ...others])
                  IosRow(
                    title: saved.displayName,
                    subtitle: saved.username == null
                        ? 'ID ${saved.telegramId}'
                        : '@${saved.username}',
                    onTap: saved.userId == account.userId
                        ? null
                        : () => ref
                              .read(switchAccountProvider.notifier)
                              .switchActiveAccount(context, saved),
                    trailing: saved.userId == account.userId
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => ref
                                .read(switchAccountProvider.notifier)
                                .removeAccount(context, saved),
                            child: Text(
                              'Remove',
                              style: TextStyle(
                                fontSize: 15,
                                color: scheme.error,
                              ),
                            ),
                          )
                        : ref.watch(switchAccountProvider).busyUserId ==
                              saved.userId
                        ? const CupertinoActivityIndicator()
                        : null,
                  ),
                IosRow(
                  title: 'Add Another Account',
                  icon: CupertinoIcons.person_add_solid,
                  onTap: () => ref
                      .read(switchAccountProvider.notifier)
                      .addAnotherAccount(context),
                ),
              ],
            ],
          ),
        ],
        IosGroup(
          title: 'YOUR LIBRARY',
          footer: 'Backup saves photos and videos to your Telegram account.',
          children: [
            IosRow(
              title: 'Photo backup',
              icon: CupertinoIcons.cloud_upload_fill,
              color: CupertinoColors.systemBlue,
              subtitle: backupOn ? 'Backup is on' : 'Backup is off',
              trailing: CupertinoSwitch(
                value: backupOn,
                onChanged: _backupBusy ? null : _setIosBackup,
              ),
            ),
            IosRow(
              title: 'Telegram Drive',
              icon: CupertinoIcons.tray_2_fill,
              color: CupertinoColors.systemIndigo,
              value: formatFileSize(summary.totalBytes),
              onTap: () => _openIosDestination('/profile?scrollToStorage=true'),
            ),
          ],
        ),
        IosGroup(
          children: [
            IosRow(
              title: 'Free Up Space',
              subtitle: 'Remove backed-up copies from this iPhone',
              icon: CupertinoIcons.device_phone_portrait,
              color: CupertinoColors.systemGreen,
              onTap: () => _openIosDestination('/profile/free-up-space'),
            ),
            IosRow(
              title: 'Settings',
              icon: CupertinoIcons.gear,
              color: CupertinoColors.systemGrey,
              onTap: () => _openIosDestination('/settings'),
            ),
            IosRow(
              title: 'My Data',
              subtitle: 'Storage, privacy and export',
              icon: CupertinoIcons.hand_raised_fill,
              color: CupertinoColors.systemBlue,
              onTap: () => _openIosDestination('/profile/my-data'),
            ),
          ],
        ),
        IosGroup(
          children: [
            IosRow(
              title: 'Help & Feedback',
              icon: CupertinoIcons.question_circle_fill,
              color: CupertinoColors.systemOrange,
              onTap: () => _showHelpFeedbackDialog(context),
            ),
          ],
        ),
        _buildAccountFooter(context),
      ],
    );
  }

  void _openIosDestination(String location) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(location);
  }

  Future<void> _setIosBackup(bool value) async {
    if (_backupBusy) return;
    _setBackupBusy(true);
    try {
      await ref
          .read(appSettingsControllerProvider)
          .setGalleryBackupEnabled(value);
      if (value)
        await ref
            .read(galleryBackupControllerProvider)
            .scanNow(reason: 'profile_toggle');
    } finally {
      if (mounted) _setBackupBusy(false);
    }
  }

  void _showIosConnectionInfo(BuildContext context, bool? connected) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          connected == true ? 'Telegram connected' : 'Telegram connection',
        ),
        content: Text(
          connected == true
              ? 'Your Telegram session is connected. TeleDrive transfers your files directly through this session.'
              : 'Open Telegram Session to check or reconnect your account.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
