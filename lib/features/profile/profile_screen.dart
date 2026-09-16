import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeletons.dart';
import 'storage_summary_controller.dart';
import 'widgets/storage_donut_card.dart';
import 'widgets/local_cache_card.dart';
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
    final controller = ref.watch(storageSummaryControllerProvider);
    final summary = controller.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/drive'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            controller.ensureLoaded(force: true),
            ref.read(cacheControllerProvider).refreshCacheStats(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Everything has its place.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Telegram library and the space used on this device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (summary == null && controller.error == null)
                      const SizedBox(height: 280, child: SkeletonList())
                    else if (summary == null)
                      EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Storage is unavailable',
                        body: controller.error!,
                        action: TextButton(
                          onPressed: () => controller.ensureLoaded(force: true),
                          child: const Text('Try again'),
                        ),
                      )
                    else ...[
                      if (controller.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Showing your last loaded storage usage. Pull to refresh.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      StorageDonutCard(
                        used: summary.totalBytes,
                        categories: buildStorageCategoriesFromSummary(summary),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const LocalCacheCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
