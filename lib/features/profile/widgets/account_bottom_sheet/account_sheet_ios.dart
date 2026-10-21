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
    return IosPage(
      title: 'Account',
      compact: true,
      controller: widget.scrollController,
      children: [
        if (account != null) ...[
          // Profile header follows the Apple Account header in Settings:
          // centered avatar, name and handle directly on the page, with the
          // Telegram details as ordinary grouped rows below it.
          Padding(
            padding: const EdgeInsets.only(
              top: 4,
              bottom: IosPageMetrics.groupSpacing,
            ),
            child: Semantics(
              button: true,
              label: 'Open Telegram profile',
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () =>
                    _openTelegramProfile(context, account.username),
                child: Column(
                  children: [
                    _buildAvatarWidget(account, size: 88),
                    const SizedBox(height: 12),
                    Text(
                      account.displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.07,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildIosTelegramGroup(context, account),
          // Saved accounts are listed directly, as in Telegram's Settings,
          // instead of behind an expanding row. The current account carries
          // the checkmark; tapping another one switches to it.
          IosGroup(
            title: 'Accounts',
            children: [
              for (final saved in [account, ...others])
                IosRow(
                  leading: _buildAvatarWidget(saved, size: 40),
                  title: saved.displayName,
                  subtitle: saved.userId != account.userId && saved.needsSignIn
                      ? 'Signed out · Tap to sign in again'
                      : saved.username == null
                      ? 'ID ${saved.telegramId}'
                      : '@${saved.username}',
                  onTap: saved.userId == account.userId
                      ? null
                      : () => ref
                            .read(switchAccountProvider.notifier)
                            .switchActiveAccount(context, saved),
                  trailing: saved.userId == account.userId
                      ? Icon(
                          CupertinoIcons.checkmark_alt,
                          color: scheme.primary,
                          semanticLabel: 'Current account',
                        )
                      : ref.watch(switchAccountProvider).busyUserId ==
                            saved.userId
                      ? const CupertinoActivityIndicator()
                      : null,
                ),
              IosRow(
                title: 'Add Account',
                icon: CupertinoIcons.person_add_solid,
                color: IosTint.neutral,
                onTap: () => ref
                    .read(switchAccountProvider.notifier)
                    .addAnotherAccount(context),
              ),
            ],
          ),
        ],
        IosGroup(
          title: 'Your Library',
          footer: 'Backup saves photos and videos to your Telegram account.',
          children: [
            IosRow(
              title: 'Photo Backup',
              icon: CupertinoIcons.cloud_upload_fill,
              color: IosTint.photoBackup,
              subtitle: backupOn ? 'Backup is on' : 'Backup is off',
              trailing: CupertinoSwitch(
                value: backupOn,
                onChanged: _backupBusy ? null : _setIosBackup,
              ),
            ),
            IosRow(
              title: 'Telegram Drive',
              icon: CupertinoIcons.tray_2_fill,
              color: IosTint.telegramDrive,
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
              color: IosTint.freeUpSpace,
              onTap: () => _openIosDestination('/profile/free-up-space'),
            ),
            IosRow(
              title: 'Settings',
              icon: CupertinoIcons.gear,
              color: IosTint.neutral,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
            IosRow(
              title: 'My Data',
              subtitle: 'Storage, privacy and export',
              icon: CupertinoIcons.hand_raised_fill,
              color: IosTint.privacy,
              onTap: () => _openIosDestination('/profile/my-data'),
            ),
          ],
        ),
        IosGroup(
          children: [
            IosRow(
              title: 'Help & Feedback',
              icon: CupertinoIcons.question_circle_fill,
              color: IosTint.help,
              onTap: () => _showHelpFeedbackDialog(context),
            ),
          ],
        ),
        if (account != null)
          IosGroup(
            children: [
              IosRow(
                title: 'Remove This Account',
                destructive: true,
                action: true,
                onTap: () => ref
                    .read(switchAccountProvider.notifier)
                    .removeAccount(context, account),
              ),
            ],
          ),
        _buildAccountFooter(context),
      ],
    );
  }

  Widget _buildIosTelegramGroup(BuildContext context, SavedAccount account) {
    final connected = ref.watch(authControllerProvider).telegramConnected;
    return IosGroup(
      children: [
        IosRow(
          title: 'Telegram',
          icon: CupertinoIcons.paperplane_fill,
          color: connected == false
              ? CupertinoColors.systemRed
              : IosTint.session,
          value: connected == true
              ? 'Connected'
              : connected == false
              ? 'Reconnect'
              : 'Connecting…',
          onTap: () => _showIosConnectionInfo(context, connected),
        ),
        IosRow(
          title: 'Telegram ID',
          icon: CupertinoIcons.number,
          color: IosTint.neutral,
          value: '${account.telegramId}',
        ),
      ],
    );
  }

  void _openIosDestination(String location) {
    context.safePush(location);
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
