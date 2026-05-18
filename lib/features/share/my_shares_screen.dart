import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/empty_state.dart';
import '../../widgets/tab_header.dart';
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
    // PageView with AutomaticKeepAlive rebuilds visible page when the tab is
    // shown again — so the build method is the right place to schedule a
    // debounced silent refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRefresh());
    final controller = ref.watch(shareControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TabHeader(
                title: 'Shared',
                subtitle: 'My shared links',
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _lastRefreshAt = DateTime.now();
                  await controller.refresh(silent: true);
                },
                child: _buildBody(controller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ShareController controller) {
    if (controller.loading && controller.shares.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.shares.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                controller.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      );
    }
    if (controller.shares.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(
            icon: Icons.ios_share,
            title: 'No active shares',
            body: 'Share a file or folder from Drive or Photos to see it here.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: controller.shares.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => ShareListTile(share: controller.shares[i]),
    );
  }
}
