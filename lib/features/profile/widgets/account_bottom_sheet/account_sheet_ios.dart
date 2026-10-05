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
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(28),
              child: ColoredBox(
                color: scheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            _openTelegramProfile(context, account.username),
                        child: Row(
                          children: [
                            _buildAvatarWidget(account, size: 60),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.displayName,
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildAccountConnectionDetails(context, account),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: IosGroup(
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
                      leading: _buildAvatarWidget(saved, size: 40),
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
          ),
        ],
        IosGroup(
          title: 'Your Library',
          footer: 'Backup saves photos and videos to your Telegram account.',
          children: [
            IosRow(
              title: 'Photo Backup',
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
