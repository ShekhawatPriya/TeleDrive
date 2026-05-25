part of '../free_up_space_screen.dart';

class _FreeUpHeroCard extends StatelessWidget {
  const _FreeUpHeroCard({required this.state});

  final FreeUpSpaceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sizeText = state.scanning
        ? 'Scanning…'
        : state.eligibleBytes > 0
        ? formatFileSize(state.eligibleBytes)
        : '0 MB';
    final countText = state.eligibleCount > 0
        ? '${state.eligibleCount} items ready'
        : 'No auto-backed-up media is ready to remove.';
    final mediaText = state.eligibleCount > 0
        ? '${state.photoCount} photos • ${state.videoCount} videos'
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.xlR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CustomPaint(
              size: const Size(138, 180),
              painter: _FreeUpSpaceIllustrationPainter(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Free up space on this device',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            sizeText,
            style: theme.textTheme.displaySmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'can be freed from this device',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This only removes local copies of photos and videos that Auto Backup has safely uploaded.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _FreeUpChip(label: countText),
              if (mediaText != null) _FreeUpChip(label: mediaText),
            ],
          ),
        ],
      ),
    );
  }
}

class _FreeUpChip extends StatelessWidget {
  const _FreeUpChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadii.lgR,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FreeUpSafetyCard extends StatelessWidget {
  const _FreeUpSafetyCard();

  @override
  Widget build(BuildContext context) {
    return const _FreeUpSectionCard(
      title: 'Safety checks',
      children: [
        _FreeUpIconRow(
          icon: Icons.cloud_done_outlined,
          text: 'Only Auto Backup items',
        ),
        _FreeUpIconRow(
          icon: Icons.verified_outlined,
          text: 'Cloud copy verified before deleting',
        ),
        _FreeUpIconRow(
          icon: Icons.block_outlined,
          text: 'Manual uploads are ignored',
        ),
        _FreeUpIconRow(
          icon: Icons.phone_android_rounded,
          text: 'Android asks before removing media',
        ),
      ],
    );
  }
}

class _FreeUpBreakdownCard extends StatelessWidget {
  const _FreeUpBreakdownCard({required this.state});

  final FreeUpSpaceState state;

  @override
  Widget build(BuildContext context) {
    return _FreeUpSectionCard(
      title: 'Breakdown',
      children: [
        _FreeUpMetricRow(
          label: 'Photos',
          value: '${state.photoCount} • ${formatFileSize(state.photoBytes)}',
        ),
        _FreeUpMetricRow(
          label: 'Videos',
          value: '${state.videoCount} • ${formatFileSize(state.videoBytes)}',
        ),
        _FreeUpMetricRow(
          label: 'Last checked',
          value: _relativeTime(state.lastScanAt),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              'Why some items are skipped?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            children: [
              _FreeUpMetricRow(
                label: 'Not backed up yet',
                value: '${state.skippedNotBackedUp}',
              ),
              _FreeUpMetricRow(
                label: 'Manual uploads ignored',
                value: '${state.skippedManualUpload}',
              ),
              _FreeUpMetricRow(
                label: 'Cloud copy unavailable',
                value: '${state.skippedRemoteMissing}',
              ),
              _FreeUpMetricRow(
                label: 'Already cleaned',
                value: '${state.skippedAlreadyCleaned}',
              ),
              _FreeUpMetricRow(
                label: 'Currently uploading',
                value: '${state.skippedCurrentlyUploading}',
              ),
              _FreeUpMetricRow(
                label: 'Unsupported local URI',
                value: '${state.skippedUnsupportedUri + state.skippedPathOnly}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _relativeTime(DateTime? value) {
    if (value == null) return 'Not checked yet';
    final elapsed = DateTime.now().difference(value);
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours} hr ago';
    return '${elapsed.inDays} days ago';
  }
}

class _FreeUpExplanationCard extends StatelessWidget {
  const _FreeUpExplanationCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _FreeUpSectionCard(
      title: 'What will be removed?',
      children: [
        Text(
          'TeleDrive will remove the local gallery copy from this phone only. Your backed-up copy remains available in TeleDrive.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'What will not be removed?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const _FreeUpIconRow(
          icon: Icons.upload_file_outlined,
          text: 'Manual uploads',
        ),
        const _FreeUpIconRow(
          icon: Icons.sync_rounded,
          text: 'Files still uploading',
        ),
        const _FreeUpIconRow(
          icon: Icons.error_outline_rounded,
          text: 'Failed backups',
        ),
        const _FreeUpIconRow(
          icon: Icons.cloud_off_outlined,
          text: 'Items not found in cloud',
        ),
        const _FreeUpIconRow(
          icon: Icons.folder_off_outlined,
          text: 'Anything outside Auto Backup',
        ),
      ],
    );
  }
}

class _FreeUpSectionCard extends StatelessWidget {
  const _FreeUpSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _FreeUpIconRow extends StatelessWidget {
  const _FreeUpIconRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeUpMetricRow extends StatelessWidget {
  const _FreeUpMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeUpMessageCard extends StatelessWidget {
  const _FreeUpMessageCard({
    required this.icon,
    required this.title,
    required this.body,
    this.subtext,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? subtext;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.36),
        borderRadius: AppRadii.lgR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtext!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _FreeUpLimitedAccessCard extends StatelessWidget {
  const _FreeUpLimitedAccessCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: AppRadii.mdR,
      ),
      child: Text(
        'Only selected photos are visible to TeleDrive. Allow full photo access to find everything that can be freed.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onTertiaryContainer,
          height: 1.35,
        ),
      ),
    );
  }
}

class _FreeUpBottomBar extends StatelessWidget {
  const _FreeUpBottomBar({
    required this.state,
    required this.onScan,
    required this.onFree,
  });

  final FreeUpSpaceState state;
  final VoidCallback onScan;
  final VoidCallback onFree;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = state.scanning
        ? 'Scanning device…'
        : state.deleting
        ? 'Waiting for Android confirmation…'
        : state.permissionDenied
        ? 'Allow photo access'
        : state.eligibleBytes <= 0
        ? 'Nothing to free up'
        : 'Free up ${formatFileSize(state.eligibleBytes)}';
    final onPressed = state.scanning || state.deleting
        ? null
        : state.permissionDenied
        ? onScan
        : state.eligibleBytes <= 0
        ? null
        : onFree;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(label),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: state.scanning || state.deleting ? null : onScan,
                child: const Text('Scan again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showFreeUpSpaceConfirmationSheet(
  BuildContext context,
  FreeUpSpaceState state,
) {
  final size = formatFileSize(state.eligibleBytes);
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Free up $size?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This removes ${state.eligibleCount} local photos/videos from this device. These items were uploaded by Auto Backup and verified in TeleDrive.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _FreeUpIconRow(
                icon: Icons.cloud_done_outlined,
                text: 'TeleDrive cloud copies stay',
              ),
              const _FreeUpIconRow(
                icon: Icons.block_outlined,
                text: 'Manual uploads are not touched',
              ),
              const _FreeUpIconRow(
                icon: Icons.sync_disabled_rounded,
                text: 'Items still uploading are skipped',
              ),
              const _FreeUpIconRow(
                icon: Icons.phone_android_rounded,
                text: 'Android will ask you to confirm',
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
