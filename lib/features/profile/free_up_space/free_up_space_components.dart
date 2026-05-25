part of '../free_up_space_screen.dart';

class _FreeUpHeroCard extends StatelessWidget {
  const _FreeUpHeroCard({required this.state});

  final FreeUpSpaceState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasItems = state.eligibleCount > 0;
    final isScanning = state.scanning;

    final (sizeMain, sizeUnit) = _splitSize(state.eligibleBytes);

    final supportText = isScanning
        ? 'Scanning your gallery for backed-up items…'
        : hasItems
            ? 'from ${state.eligibleCount} items on this device'
            : 'Nothing on this device is ready to remove.';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadii.xlR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'RECLAIMABLE ON THIS DEVICE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isScanning)
            _ScanningSizePlaceholder()
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  sizeMain,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -1.4,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    sizeUnit,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            supportText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (hasItems && !isScanning) ...[
            const SizedBox(height: AppSpacing.lg),
            _MediaProportionBar(
              photoBytes: state.photoBytes,
              videoBytes: state.videoBytes,
              photoCount: state.photoCount,
              videoCount: state.videoCount,
            ),
          ],
        ],
      ),
    );
  }

  static (String, String) _splitSize(int bytes) {
    final formatted = bytes > 0 ? formatFileSize(bytes) : '0 MB';
    final parts = formatted.split(' ');
    if (parts.length == 2) return (parts[0], parts[1]);
    return (formatted, '');
  }
}

class _ScanningSizePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Calculating…',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _MediaProportionBar extends StatelessWidget {
  const _MediaProportionBar({
    required this.photoBytes,
    required this.videoBytes,
    required this.photoCount,
    required this.videoCount,
  });

  final int photoBytes;
  final int videoBytes;
  final int photoCount;
  final int videoCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = photoBytes + videoBytes;
    final photoFraction = total > 0 ? photoBytes / total : 0.5;
    final videoFraction = total > 0 ? videoBytes / total : 0.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (photoFraction > 0)
                  Expanded(
                    flex: (photoFraction * 1000).round().clamp(1, 1000),
                    child: Container(color: scheme.primary),
                  ),
                if (photoFraction > 0 && videoFraction > 0)
                  const SizedBox(width: 2),
                if (videoFraction > 0)
                  Expanded(
                    flex: (videoFraction * 1000).round().clamp(1, 1000),
                    child: Container(
                      color: scheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _LegendDot(
              color: scheme.primary,
              label: '$photoCount photos',
            ),
            const SizedBox(width: AppSpacing.md),
            _LegendDot(
              color: scheme.primary.withValues(alpha: 0.45),
              label: '$videoCount videos',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FreeUpSafetyCard extends StatelessWidget {
  const _FreeUpSafetyCard();

  @override
  Widget build(BuildContext context) {
    return const _FreeUpSectionCard(
      title: 'Safety checks',
      subtitle: 'What we always verify before deleting',
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
          isLast: true,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _FreeUpSectionCard(
      title: 'Breakdown',
      subtitle: _relativeTime(state.lastScanAt),
      children: [
        _MediaBreakdownRow(
          icon: Icons.photo_outlined,
          label: 'Photos',
          count: state.photoCount,
          size: formatFileSize(state.photoBytes),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MediaBreakdownRow(
          icon: Icons.movie_outlined,
          label: 'Videos',
          count: state.videoCount,
          size: formatFileSize(state.videoBytes),
          isLast: true,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
        Theme(
          data: theme.copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: AppSpacing.xs),
            iconColor: scheme.onSurfaceVariant,
            collapsedIconColor: scheme.onSurfaceVariant,
            title: Text(
              'Why some items are skipped',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
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
                isLast: true,
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
    if (elapsed.inMinutes < 1) return 'Updated just now';
    if (elapsed.inHours < 1) return 'Updated ${elapsed.inMinutes} min ago';
    if (elapsed.inDays < 1) return 'Updated ${elapsed.inHours} hr ago';
    return 'Updated ${elapsed.inDays} days ago';
  }
}

class _MediaBreakdownRow extends StatelessWidget {
  const _MediaBreakdownRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.size,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final String size;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: AppRadii.smR,
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$count items',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          size,
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _FreeUpExplanationCard extends StatelessWidget {
  const _FreeUpExplanationCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _FreeUpSectionCard(
      title: 'What gets removed',
      subtitle: 'Local gallery copies only — your cloud stays untouched',
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.05),
            borderRadius: AppRadii.mdR,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_done_outlined,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'TeleDrive removes the local gallery copy from this phone only. Your backed-up copy remains available in TeleDrive.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Never touched',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
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
          isLast: true,
        ),
      ],
    );
  }
}

class _FreeUpSectionCard extends StatelessWidget {
  const _FreeUpSectionCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _FreeUpIconRow extends StatelessWidget {
  const _FreeUpIconRow({
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  final IconData icon;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeUpMetricRow extends StatelessWidget {
  const _FreeUpMetricRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xs),
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
              fontFeatures: const [FontFeature.tabularFigures()],
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
        color: scheme.secondaryContainer.withValues(alpha: 0.32),
        borderRadius: AppRadii.lgR,
        border: Border.all(
          color: scheme.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.14),
              borderRadius: AppRadii.smR,
            ),
            child: Icon(icon, color: scheme.onSecondaryContainer, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtext!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _FreeUpLimitedAccessCard extends StatelessWidget {
  const _FreeUpLimitedAccessCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.40),
        borderRadius: AppRadii.mdR,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: scheme.onTertiaryContainer,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Only selected photos are visible to TeleDrive. Allow full photo access to find everything that can be freed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onTertiaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
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

    final helperText = state.scanning
        ? 'Checking which items are safe to remove…'
        : state.deleting
            ? 'Confirm in the system dialog to continue.'
            : state.permissionDenied
                ? 'TeleDrive needs photo access to find backed-up items.'
                : state.eligibleBytes <= 0
                    ? 'Run a scan when more items have been backed up.'
                    : 'Cloud copies remain in TeleDrive.';

    final onPressed = state.scanning || state.deleting
        ? null
        : state.permissionDenied
            ? onScan
            : state.eligibleBytes <= 0
                ? null
                : onFree;

    final isBusy = state.scanning || state.deleting;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.22),
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
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                child: isBusy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(label),
                        ],
                      )
                    : Text(label),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                helperText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
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
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: AppRadii.smR,
                ),
                child: Text(
                  'CONFIRM',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Free up $size?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Removes ${state.eligibleCount} local photos and videos that Auto Backup uploaded and verified.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppRadii.mdR,
                ),
                child: Column(
                  children: const [
                    _FreeUpIconRow(
                      icon: Icons.cloud_done_outlined,
                      text: 'TeleDrive cloud copies stay',
                    ),
                    _FreeUpIconRow(
                      icon: Icons.block_outlined,
                      text: 'Manual uploads are not touched',
                    ),
                    _FreeUpIconRow(
                      icon: Icons.sync_disabled_rounded,
                      text: 'Items still uploading are skipped',
                    ),
                    _FreeUpIconRow(
                      icon: Icons.phone_android_rounded,
                      text: 'Android will ask you to confirm',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Continue'),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
