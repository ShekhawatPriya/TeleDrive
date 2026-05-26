import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'storage_summary_controller.dart';
import 'widgets/storage_swipe_card.dart';
import 'widgets/storage_donut_card.dart';
import 'cache_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.scrollToStorage = false, super.key});
  final bool scrollToStorage;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(cacheControllerProvider).refreshCacheStats();
      ref.read(storageSummaryControllerProvider).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        ref.watch(storageSummaryControllerProvider).value ?? StorageSummary.empty;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final used = summary.totalBytes;
    final categories = buildStorageCategoriesFromSummary(summary);

    final modalRoute = ModalRoute.of(context);
    final isCurrent = modalRoute?.isCurrent ?? true;

    return PopScope(
      canPop: !isCurrent || GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isCurrent) {
          context.go('/drive');
        }
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () {
                  if (GoRouter.of(context).canPop()) {
                    context.pop();
                  } else {
                    context.go('/drive');
                  }
                },
              ),
              title: const Text('Storage'),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    child: Text(
                      'Storage Breakdown',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  StorageSwipeCard(used: used, categories: categories),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
