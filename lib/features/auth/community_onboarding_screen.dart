import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'components/community_promise_list.dart';
import 'components/community_target_panel.dart';
import 'components/login_controls.dart';
import 'models/community_onboarding.dart';
import '../../widgets/ios/ios_page.dart';

class CommunityOnboardingScreen extends ConsumerStatefulWidget {
  const CommunityOnboardingScreen({super.key});

  @override
  ConsumerState<CommunityOnboardingScreen> createState() =>
      _CommunityOnboardingScreenState();
}

class _CommunityOnboardingScreenState
    extends ConsumerState<CommunityOnboardingScreen> {
  bool _loading = false;

  Future<void> _continue() async {
    if (_loading) return;
    setState(() => _loading = true);
    await ref.read(authControllerProvider).completeCommunityOnboarding();
    if (mounted) context.go('/drive');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (theme.platform == TargetPlatform.iOS) {
      return _IosCommunityOnboarding(
        targets: auth.communityTargets,
        loading: _loading,
        onContinue: _continue,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ConnectedHeader(),
                  const SizedBox(height: AppSpacing.xxs),
                  Center(
                    child: Lottie.asset(
                      'assets/animations/green_tick.json',
                      width: 60,
                      height: 60,
                      repeat: false,
                      animate: !MediaQuery.disableAnimationsOf(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Account Connected!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Welcome to TeleDrive',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Community setup keeps official DevsDoCode support, updates, and announcements close while your drive finishes preparing.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  CommunityTargetPanel(targets: auth.communityTargets),
                  const SizedBox(height: AppSpacing.xl),
                  const CommunityPromiseList(),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Continue setup'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectedHeader extends StatelessWidget {
  const _ConnectedHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/icon/telegram.png', width: 74, height: 74),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            '· · · ·',
            style: TextStyle(
              fontSize: 24,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ),
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .28),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset('assets/icon/devsdocode.png', fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}

/// iOS: the connection as two app marks joined by a check, a plain title,
/// the community destinations and the transparency promise as inset groups,
/// and Continue pinned above the home indicator.
class _IosCommunityOnboarding extends StatelessWidget {
  const _IosCommunityOnboarding({
    required this.targets,
    required this.loading,
    required this.onContinue,
  });
  final List<CommunityTarget> targets;
  final bool loading;
  final VoidCallback onContinue;

  static const _promiseSymbols = [
    CupertinoIcons.person_3_fill,
    CupertinoIcons.arrow_right_square_fill,
    CupertinoIcons.cloud_fill,
    CupertinoIcons.lock_shield_fill,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 36, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _IosConnectionMark(),
                        const SizedBox(height: 24),
                        Semantics(
                          header: true,
                          child: Text(
                            'You’re Connected',
                            textScaler: MediaQuery.textScalerOf(
                              context,
                            ).clamp(maxScaleFactor: 1.35),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'CupertinoSystemDisplay',
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.5,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Your Telegram account is linked. Community setup '
                            'keeps official DevsDoCode support, updates and '
                            'announcements close while your drive finishes '
                            'preparing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              letterSpacing: -.3,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (targets.isNotEmpty)
                          IosGroup(
                            title: 'Community',
                            children: [
                              for (final target in targets)
                                IosRow(
                                  title: target.name,
                                  subtitle: target.label,
                                  icon: target.kind == 'group'
                                      ? CupertinoIcons.person_3_fill
                                      : CupertinoIcons.speaker_2_fill,
                                  color: target.kind == 'group'
                                      ? CupertinoColors.systemBlue
                                      : CupertinoColors.systemOrange,
                                ),
                            ],
                          ),
                        IosGroup(
                          title: 'Our Transparency Promise',
                          bottomSpacing: 0,
                          dividerInset: 52,
                          children: [
                            for (
                              var i = 0;
                              i < CommunityPromiseList.items.length;
                              i++
                            )
                              _IosPromise(
                                icon:
                                    _promiseSymbols[i % _promiseSymbols.length],
                                text: CommunityPromiseList.items[i].$2,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: LoginPrimaryButton(
                  label: 'Continue',
                  busy: loading,
                  onPressed: onContinue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IosPromise extends StatelessWidget {
  const _IosPromise({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Icon(
              icon,
              size: 19,
              color: CupertinoColors.systemBlue.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.38,
                letterSpacing: -.2,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Telegram and TeleDrive side by side, joined by a green check.
class _IosConnectionMark extends StatelessWidget {
  const _IosConnectionMark();

  @override
  Widget build(BuildContext context) {
    final green = CupertinoColors.systemGreen.resolveFrom(context);
    final dots = CupertinoColors.tertiaryLabel.resolveFrom(context);
    Widget dot() => Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(color: dots, shape: BoxShape.circle),
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/icon/telegram.png',
            width: 68,
            height: 68,
            cacheWidth: 204,
          ),
          const SizedBox(width: 10),
          dot(),
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: green, shape: BoxShape.circle),
            child: const Icon(
              CupertinoIcons.checkmark_alt,
              size: 18,
              color: Colors.white,
            ),
          ),
          dot(),
          const SizedBox(width: 10),
          ClipRSuperellipse(
            borderRadius: BorderRadius.circular(15),
            child: Image.asset(
              'assets/icon/app_icon_ios.png',
              width: 68,
              height: 68,
              cacheWidth: 204,
            ),
          ),
        ],
      ),
    );
  }
}
