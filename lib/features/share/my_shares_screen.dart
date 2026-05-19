import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/auth_controller.dart';
import 'components/share_list_tile.dart';
import 'share_controller.dart';

class MySharesScreen extends ConsumerStatefulWidget {
  const MySharesScreen({super.key});

  @override
  ConsumerState<MySharesScreen> createState() => _MySharesScreenState();
}

class _MySharesScreenState extends ConsumerState<MySharesScreen>
    with WidgetsBindingObserver {
  DateTime? _lastRefreshAt;
  static const _refreshTtl = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRefresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRefresh();
    }
  }

  void _maybeRefresh({bool force = false}) {
    if (!mounted) return;
    final now = DateTime.now();
    if (!force &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < _refreshTtl) {
      return;
    }
    _lastRefreshAt = now;
    ref.read(shareControllerProvider).refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRefresh());
    final controller = ref.watch(shareControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final shareCount = controller.shares.length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _lastRefreshAt = DateTime.now();
          await controller.refresh(silent: true);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar.medium(
              pinned: true,
              expandedHeight: 128,
              title: Text('Shared', style: theme.textTheme.titleLarge),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                title: Text(
                  shareCount == 0
                      ? 'My shared links'
                      : '$shareCount link${shareCount == 1 ? '' : 's'}',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      0, 0, AppSpacing.sm, 0),
                  child: GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: ProfileAvatar(user: auth.user, size: 36),
                  ),
                ),
              ],
            ),
            ..._buildBody(controller),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(ShareController controller) {
    if (controller.loading && controller.shares.isEmpty) {
      return const [
        SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      ];
    }
    if (controller.error != null && controller.shares.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                controller.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
      ];
    }
    if (controller.shares.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.share_outlined,
            title: 'No active shares',
            body:
                'Share a file or folder from Drive or Photos to see it here.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        sliver: SliverList.builder(
          itemCount: controller.shares.length,
          itemBuilder: (_, i) => ShareListTile(share: controller.shares[i]),
        ),
      ),
    ];
  }
}
