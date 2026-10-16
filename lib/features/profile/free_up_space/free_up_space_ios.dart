part of '../free_up_space_screen.dart';

extension _IosFreeUpSpace on _FreeUpSpaceScreenState {
  Widget _buildIosFreeUp(
    BuildContext context,
    FreeUpSpaceController controller,
    FreeUpSpaceState state,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = state.scanning || state.deleting;
    return IosPage(
      title: 'Free Up Space',
      compact: true,
      // Only the destructive step earns a pinned button; rescanning is an
      // ordinary action row, as in Settings.
      footer: state.eligibleCount > 0 || state.deleting
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: .5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: CupertinoButton.filled(
                  borderRadius: BorderRadius.circular(28),
                  onPressed: busy
                      ? null
                      : () => _confirmAndFree(context, controller, state),
                  child: Text(
                    state.deleting
                        ? 'Removing…'
                        : 'Free Up ${formatStorageSize(state.eligibleBytes)}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : null,
      children: [
        const IosSettingsIntro(
          icon: CupertinoIcons.device_phone_portrait,
          color: IosTint.freeUpSpace,
          title: 'Free Up Space',
          description:
              'Remove photos and videos from this iPhone once their backups are verified in Telegram.',
        ),
        IosGroup(
          footer: state.scanning
              ? 'Checking backed-up photos and videos…'
              : state.eligibleCount == 0 &&
                    !state.permissionDenied &&
                    state.error == null
              ? 'You’re all clear. No verified Auto Backup copies are ready to remove.'
              : 'Only local copies are removed. iOS asks you to confirm before anything leaves Photos, and your backups stay in Telegram.',
          children: [
            IosRow(
              title: 'Ready to Remove',
              value: state.scanning
                  ? null
                  : formatStorageSize(state.eligibleBytes),
              trailing: state.scanning
                  ? const CupertinoActivityIndicator()
                  : null,
            ),
            if (state.eligibleCount == 0 && !state.deleting)
              IosRow(
                title: state.scanning ? 'Checking Photos…' : 'Check Again',
                action: true,
                enabled: !busy,
                trailing: const SizedBox.shrink(),
                onTap: busy ? null : () => controller.scan(),
              ),
          ],
        ),
        if (state.permissionDenied)
          IosGroup(
            children: [
              IosRow(
                title: 'Photo Access Needed',
                subtitle: 'Allow access to find backed-up photos and videos.',
                icon: CupertinoIcons.photo,
                onTap: () => controller.scan(),
              ),
            ],
          )
        else if (state.error != null)
          IosGroup(
            children: [
              IosRow(
                title: 'Couldn’t Verify Cloud Copies',
                subtitle: state.error,
                icon: CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.systemOrange,
                onTap: () => controller.scan(),
              ),
            ],
          ),
        if (state.limitedAccess)
          const IosNote(
            'Limited Photos access: only the items you have allowed are included in this check.',
          ),
        IosGroup(
          title: 'Verified Backups',
          footer: _FreeUpBreakdownCard._relativeTime(state.lastScanAt),
          children: [
            IosRow(
              title: 'Photos',
              subtitle: '${state.photoCount} items',
              value: formatStorageSize(state.photoBytes),
              icon: CupertinoIcons.photo_fill,
              color: IosTint.photos,
            ),
            IosRow(
              title: 'Videos',
              subtitle: '${state.videoCount} items',
              value: formatStorageSize(state.videoBytes),
              icon: CupertinoIcons.videocam_fill,
              color: IosTint.videos,
            ),
          ],
        ),
        IosGroup(
          title: 'Items Kept on This iPhone',
          children: [
            IosRow(
              title: 'Not Backed Up',
              value: '${state.skippedNotBackedUp}',
            ),
            IosRow(
              title: 'Manual Uploads',
              value: '${state.skippedManualUpload}',
            ),
            IosRow(
              title: 'Cloud Copy Unavailable',
              value: '${state.skippedRemoteMissing}',
            ),
            IosRow(
              title: 'Still Uploading',
              value: '${state.skippedCurrentlyUploading}',
            ),
            IosRow(
              title: 'Already Cleaned',
              value: '${state.skippedAlreadyCleaned}',
            ),
            IosRow(
              title: 'Unavailable Local Items',
              value: '${state.skippedUnsupportedUri + state.skippedPathOnly}',
            ),
          ],
        ),
      ],
    );
  }
}
