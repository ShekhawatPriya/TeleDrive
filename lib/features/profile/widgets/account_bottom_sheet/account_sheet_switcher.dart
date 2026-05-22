part of '../account_bottom_sheet.dart';

extension _AccountSheetSwitcher on _AccountBottomSheetState {
  Widget _buildSwitchAccountCard(
    BuildContext context,
    SavedAccount activeAccount,
    List<SavedAccount> otherAccounts,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final switchState = ref.watch(switchAccountProvider);
    final notifier = ref.read(switchAccountProvider.notifier);

    return _ProfileSheetSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _toggleSwitchAccountCard(notifier),
            borderRadius: _isExpanded
                ? const BorderRadius.vertical(
                    top: Radius.circular(
                      _AccountBottomSheetState._sectionRadius,
                    ),
                  )
                : BorderRadius.circular(
                    _AccountBottomSheetState._sectionRadius,
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 22,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Switch account',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (!_isExpanded && otherAccounts.isNotEmpty) ...[
                    _buildOverlappingAvatars(context, otherAccounts),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: _profileSectionDividerColor(scheme),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: switchState.accounts.length,
                      itemBuilder: (context, index) {
                        final account = switchState.accounts[index];
                        final isActive =
                            account.userId == switchState.activeUserId;
                        final isBusy = account.userId == switchState.busyUserId;

                        return InkWell(
                          key: ValueKey(
                            'switch-account-${account.userId}-${account.resolvedPhotoUrl ?? 'fallback'}',
                          ),
                          onTap: () {
                            if (switchState.isRemoveMode || isActive) return;
                            notifier.switchActiveAccount(context, account);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _buildAvatarWidget(account, size: 40),
                                    if (switchState.isRemoveMode)
                                      Positioned(
                                        top: -6,
                                        left: -6,
                                        child: GestureDetector(
                                          onTap: () => notifier.removeAccount(
                                            context,
                                            account,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.displayName,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: scheme.onSurface,
                                            ),
                                      ),
                                      Text(
                                        account.username != null &&
                                                account.username!.isNotEmpty
                                            ? '@${account.username}'
                                            : 'ID ${account.telegramId}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isBusy)
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.primary,
                                    ),
                                  )
                                else if (isActive && !switchState.isRemoveMode)
                                  TextButton(
                                    onPressed: () => notifier.removeAccount(
                                      context,
                                      account,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: scheme.error,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Remove'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Divider(
                      color: _profileSectionDividerColor(scheme),
                      height: 1,
                    ),
                  ),
                  _buildSwitchOptionRow(
                    context,
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Add another account',
                    onTap: () => notifier.addAnotherAccount(context),
                  ),
                  _buildSwitchOptionRow(
                    context,
                    icon: switchState.isRemoveMode
                        ? Icons.check_circle_outline_rounded
                        : Icons.manage_accounts_outlined,
                    label: switchState.isRemoveMode
                        ? 'Done removing'
                        : 'Remove account',
                    onTap: notifier.toggleRemoveMode,
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchOptionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, color: scheme.onSurfaceVariant, size: 20),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
