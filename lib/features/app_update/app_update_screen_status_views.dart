part of 'app_update_screen.dart';

enum _UpdateStatus { checking, upToDate, available, error }

class _CheckingView extends StatelessWidget {
  const _CheckingView({required this.packageInfo});

  final PackageInfo? packageInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          _StatusHero(
            icon: Icons.sync_rounded,
            tone: _HeroTone.neutral,
            spinning: true,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Checking for updates',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reaching out to the release server. This usually takes a moment.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          if (packageInfo != null)
            _CurrentVersionFootnote(packageInfo: packageInfo!),
        ],
      ),
    );
  }
}

class _UpToDateView extends StatelessWidget {
  const _UpToDateView({required this.packageInfo, required this.onRecheck});

  final PackageInfo? packageInfo;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          const _StatusHero(icon: Icons.check_rounded, tone: _HeroTone.success),
          const SizedBox(height: AppSpacing.xl),
          Text(
            "You're up to date",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'TeleDrive is running the latest version available. We will let you know when something new arrives.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (packageInfo != null) _VersionPanel(packageInfo: packageInfo!),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onRecheck,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Check again'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableView extends StatelessWidget {
  const _AvailableView({
    required this.info,
    required this.onDownload,
    required this.onRecheck,
  });

  final AppUpdateInfo info;
  final Future<void> Function() onDownload;
  final Future<void> Function() onRecheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        const _StatusHero(
          icon: Icons.system_update_rounded,
          tone: _HeroTone.accent,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          info.mandatory ? 'Update required' : 'Update available',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          info.mandatory
              ? 'A required update is ready. Install it to keep using TeleDrive.'
              : 'A newer version of TeleDrive is ready to install.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        _VersionDeltaCard(info: info),
        if (info.releaseNotes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _ReleaseNotesCard(notes: info.releaseNotes),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: () => onDownload(),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download update'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(borderRadius: AppRadii.lgR),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => onRecheck(),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Check again'),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          const _StatusHero(
            icon: Icons.cloud_off_rounded,
            tone: _HeroTone.warning,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            "Couldn't check for updates",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.lgR),
            ),
          ),
        ],
      ),
    );
  }
}
