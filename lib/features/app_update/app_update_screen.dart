import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_theme.dart';
import 'app_update_controller.dart';
import 'app_update_models.dart';

class AppUpdateScreen extends ConsumerStatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  ConsumerState<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends ConsumerState<AppUpdateScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(appUpdateControllerProvider);
      controller.clearManualMessages();
      controller.checkForUpdate(reason: AppUpdateCheckReason.dedicatedScreen);
    });
  }

  Future<void> _recheck() async {
    final controller = ref.read(appUpdateControllerProvider);
    controller.clearManualMessages();
    await controller.checkForUpdate(
      reason: AppUpdateCheckReason.dedicatedScreen,
    );
  }

  Future<void> _download() async {
    final ok = await ref.read(appUpdateControllerProvider).openDownload();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the download link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appUpdateControllerProvider);
    final state = controller.state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final status = _resolveStatus(state);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('App Update'),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(status),
            child: _buildBody(context, status, state),
          ),
        ),
      ),
    );
  }

  _UpdateStatus _resolveStatus(AppUpdateState state) {
    if (state.isChecking) return _UpdateStatus.checking;
    if (state.lastError != null) return _UpdateStatus.error;
    if (state.update != null) return _UpdateStatus.available;
    return _UpdateStatus.upToDate;
  }

  Widget _buildBody(
    BuildContext context,
    _UpdateStatus status,
    AppUpdateState state,
  ) {
    switch (status) {
      case _UpdateStatus.checking:
        return _CheckingView(packageInfo: _packageInfo);
      case _UpdateStatus.upToDate:
        return _UpToDateView(
          packageInfo: _packageInfo,
          onRecheck: _recheck,
        );
      case _UpdateStatus.available:
        return _AvailableView(
          info: state.update!,
          onDownload: _download,
          onRecheck: _recheck,
        );
      case _UpdateStatus.error:
        return _ErrorView(
          message: state.lastError ?? 'Something went wrong',
          onRetry: _recheck,
        );
    }
  }
}

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
          const _StatusHero(
            icon: Icons.check_rounded,
            tone: _HeroTone.success,
          ),
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

enum _HeroTone { neutral, accent, success, warning }

class _StatusHero extends StatefulWidget {
  const _StatusHero({
    required this.icon,
    required this.tone,
    this.spinning = false,
  });

  final IconData icon;
  final _HeroTone tone;
  final bool spinning;

  @override
  State<_StatusHero> createState() => _StatusHeroState();
}

class _StatusHeroState extends State<_StatusHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _StatusHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.spinning && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color bg, Color fg, Color ring) = switch (widget.tone) {
      _HeroTone.neutral => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        scheme.outlineVariant,
      ),
      _HeroTone.accent => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primary.withValues(alpha: 0.18),
      ),
      _HeroTone.success => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        scheme.tertiary.withValues(alpha: 0.18),
      ),
      _HeroTone.warning => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        scheme.error.withValues(alpha: 0.18),
      ),
    };

    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: ring, width: 1),
      ),
      alignment: Alignment.center,
      child: RotationTransition(
        turns: _spin,
        child: Icon(widget.icon, size: 56, color: fg),
      ),
    );
  }
}

class _VersionPanel extends StatelessWidget {
  const _VersionPanel({required this.packageInfo});

  final PackageInfo packageInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.verified_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Installed version',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'v${packageInfo.version} · build ${packageInfo.buildNumber}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentVersionFootnote extends StatelessWidget {
  const _CurrentVersionFootnote({required this.packageInfo});

  final PackageInfo packageInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Text(
      'Currently on v${packageInfo.version} · build ${packageInfo.buildNumber}',
      style: theme.textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _VersionDeltaCard extends StatelessWidget {
  const _VersionDeltaCard({required this.info});

  final AppUpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VersionPill(
              label: 'Installed',
              version: info.installedVersionName,
              dim: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: scheme.onSurfaceVariant,
              size: 18,
            ),
          ),
          Expanded(
            child: _VersionPill(
              label: 'Latest',
              version: info.latestVersionName,
              dim: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({
    required this.label,
    required this.version,
    required this.dim,
  });

  final String label;
  final String version;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = dim ? scheme.onSurfaceVariant : scheme.onPrimaryContainer;
    final bg = dim ? scheme.surfaceContainerHigh : scheme.primaryContainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'v$version',
            style: theme.textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReleaseNotesCard extends StatelessWidget {
  const _ReleaseNotesCard({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgR,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's new",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
