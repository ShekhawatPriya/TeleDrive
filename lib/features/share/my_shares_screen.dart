import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/share_models.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/adaptive_surface.dart';
import '../drive/view_preferences_controller.dart';
import '../search/search_controller.dart';
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
    final controller = ref.watch(shareControllerProvider);
    final prefs = ref.watch(viewPreferencesProvider);
    final query = ref.watch(searchQueryProvider(SearchScope.shared)).query;
    final filtered = _applyQuery(controller.shares, query);
    final shareCount = filtered.length;
    final grid =
        prefs.layout == LayoutMode.grid &&
        MediaQuery.textScalerOf(context).scale(14) <= 22;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _lastRefreshAt = DateTime.now();
          await controller.refresh(silent: true);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            query.isEmpty
                                ? 'Manage access and see link activity.'
                                : 'Shared links matching your search.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$shareCount ${query.isEmpty ? (shareCount == 1 ? 'shared link' : 'shared links') : 'matches'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    )
                  : CollectionIntro(
                      title: query.isEmpty
                          ? 'A link brings it together.'
                          : 'Search results',
                      description: query.isEmpty
                          ? 'Manage access and see how your files are being shared.'
                          : 'Shared links matching your search.',
                      icon: Theme.of(context).platform == TargetPlatform.iOS
                          ? CupertinoIcons.link
                          : Icons.link_rounded,
                      detail:
                          '$shareCount ${query.isEmpty ? 'shared links' : 'matches'}',
                    ),
            ),
            ..._buildBody(controller, filtered, query, grid),
          ],
        ),
      ),
    );
  }

  List<Share> _applyQuery(List<Share> shares, String query) {
    if (query.isEmpty) return shares;
    return shares.where((s) {
      final primary = s.primaryName?.toLowerCase() ?? '';
      if (primary.contains(query)) return true;
      return s.items.any((it) => it.name.toLowerCase().contains(query));
    }).toList();
  }

  List<Widget> _buildBody(
    ShareController controller,
    List<Share> filtered,
    String query,
    bool grid,
  ) {
    if (controller.loading && controller.shares.isEmpty) {
      return const [
        SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
      ];
    }
    if (controller.error != null && controller.shares.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load shared links',
            body: controller.error!,
            action: TextButton(
              onPressed: () => controller.refresh(),
              child: const Text('Try again'),
            ),
          ),
        ),
      ];
    }
    if (filtered.isEmpty) {
      final searching = query.isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: searching ? Icons.search_off : Icons.share_outlined,
            title: searching ? 'No matching shares' : 'No active shares',
            body: searching
                ? 'Try a different name.'
                : 'Share a file or folder from Drive or Photos to see it here.',
          ),
        ),
      ];
    }
    return grid
        ? [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                160,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  childAspectRatio: .72,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) => ShareCardTile(share: filtered[i]),
              ),
            ),
          ]
        : [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 160),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => ShareListTile(share: filtered[i]),
              ),
            ),
          ];
  }
}
