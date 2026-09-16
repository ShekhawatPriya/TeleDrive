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
      trailing: NativeGlassButton(
        label: 'Scan again',
        symbol: 'arrow.clockwise',
        icon: CupertinoIcons.refresh,
        onPressed: busy ? null : () => controller.scan(),
      ),
      footer: DecoratedBox(
        decoration: BoxDecoration(color: scheme.surface),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: CupertinoButton.filled(
            borderRadius: BorderRadius.circular(28),
            onPressed: busy
                ? null
                : state.eligibleCount > 0
                ? () => _confirmAndFree(context, controller, state)
                : () => controller.scan(),
            child: Text(
              state.deleting
                  ? 'Removing…'
                  : state.scanning
                  ? 'Checking Photos…'
                  : state.eligibleCount > 0
                  ? 'Free Up ${formatFileSize(state.eligibleBytes)}'
                  : 'Check Again',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      children: [
        const SizedBox(height: 12),
        Icon(
          CupertinoIcons.device_phone_portrait,
          size: 56,
          color: scheme.primary,
        ),
        const SizedBox(height: 18),
        if (state.scanning)
          const Center(child: CupertinoActivityIndicator(radius: 14))
        else
          Text(
            formatFileSize(state.eligibleBytes),
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall,
          ),
        const SizedBox(height: 8),
        Text(
          state.scanning
              ? 'Checking backed-up photos and videos'
              : 'Available to free up on this iPhone',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        if (state.permissionDenied)
          IosGroup(
            children: [
              IosRow(
                title: 'Photo access needed',
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
                title: 'Couldn’t verify cloud copies',
                subtitle: state.error,
                icon: CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.systemOrange,
                onTap: () => controller.scan(),
              ),
            ],
          )
        else if (!state.scanning && state.eligibleCount == 0)
          const IosNote(
            'You’re all clear. No verified Auto Backup copies are ready to remove.',
          ),
        if (state.limitedAccess)
          const IosNote(
            'Limited Photos access: only the items you have allowed are included in this check.',
          ),
        IosGroup(
          title: 'VERIFIED BACKUPS',
          footer: _FreeUpBreakdownCard._relativeTime(state.lastScanAt),
          children: [
            IosRow(
              title: 'Photos',
              subtitle: '${state.photoCount} items',
              value: formatFileSize(state.photoBytes),
              icon: CupertinoIcons.photo_fill,
              color: CupertinoColors.systemPink,
            ),
            IosRow(
              title: 'Videos',
              subtitle: '${state.videoCount} items',
              value: formatFileSize(state.videoBytes),
              icon: CupertinoIcons.videocam_fill,
              color: CupertinoColors.systemOrange,
            ),
          ],
        ),
        const IosGroup(
          title: 'WHAT HAPPENS NEXT',
          children: [
            IosRow(
              title: 'Only local copies are removed',
              subtitle:
                  'Your verified backups stay in Telegram. You can view or download them again in TeleDrive.',
              icon: CupertinoIcons.cloud_fill,
            ),
            IosRow(
              title: 'You stay in control',
              subtitle:
                  'iOS asks you to confirm removal from Photos. Cancel to keep everything on this iPhone.',
              icon: CupertinoIcons.hand_raised_fill,
              color: CupertinoColors.systemGreen,
            ),
          ],
        ),
        IosGroup(
          title: 'ITEMS KEPT ON THIS IPHONE',
          children: [
            IosRow(
              title: 'Not backed up',
              value: '${state.skippedNotBackedUp}',
            ),
            IosRow(
              title: 'Manual uploads',
              value: '${state.skippedManualUpload}',
            ),
            IosRow(
              title: 'Cloud copy unavailable',
              value: '${state.skippedRemoteMissing}',
            ),
            IosRow(
              title: 'Still uploading',
              value: '${state.skippedCurrentlyUploading}',
            ),
            IosRow(
              title: 'Already cleaned',
              value: '${state.skippedAlreadyCleaned}',
            ),
            IosRow(
              title: 'Unavailable local items',
              value: '${state.skippedUnsupportedUri + state.skippedPathOnly}',
            ),
          ],
        ),
      ],
    );
  }
}
