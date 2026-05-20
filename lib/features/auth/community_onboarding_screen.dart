import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                  const SizedBox(height: AppSpacing.lg),
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
        _IconBubble(
          asset: 'assets/icon/telegram.png',
          background: const Color(0xFF229ED9),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 30,
          ),
        ),
        _IconBubble(
          asset: 'assets/icon/devsdocode.png',
          background: Theme.of(context).colorScheme.primaryContainer,
        ),
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.asset, required this.background});

  final String asset;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: .28),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
