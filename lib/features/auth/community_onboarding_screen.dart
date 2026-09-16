import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'components/community_promise_list.dart';
import 'components/community_target_panel.dart';

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
