import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import '../../widgets/ios/ios_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeletons.dart';
import 'changelog_controller.dart';
import 'github_release_models.dart';
import 'release_notes.dart';

part 'changelog_screen_widgets.dart';

class ChangelogScreen extends ConsumerStatefulWidget {
  const ChangelogScreen({super.key});

  @override
  ConsumerState<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends ConsumerState<ChangelogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(changelogControllerProvider).load();
    });
  }

  Future<void> _refresh() =>
      ref.read(changelogControllerProvider).load(force: true);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changelogControllerProvider).state;

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return IosPage(
        title: 'What’s New',
        compact: true,
        horizontalPadding: 20,
        onRefresh: _refresh,
        children: [
          ..._introduction(context, state),
          if (state.isLoading && state.releases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CupertinoActivityIndicator(),
            )
          else if (state.releases.isEmpty)
            IosGroup(
              children: [
                IosRow(
                  title: state.error == null
                      ? 'No Releases Yet'
                      : 'Could Not Load Releases',
                  subtitle: state.error == null
                      ? 'Published releases will appear here.'
                      : 'Check your connection and try again.',
                ),
                IosRow(
                  title: 'Refresh',
                  action: true,
                  trailing: const SizedBox.shrink(),
                  onTap: _refresh,
                ),
              ],
            )
          else
            for (var i = 0; i < state.releases.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ReleaseCard(
                  key: ValueKey(
                    state.releases[i].htmlUrl + state.releases[i].tagName,
                  ),
                  release: state.releases[i],
                  isLatest: i == 0,
                ),
              ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('What’s New'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ChangelogState state) {
    if (state.isLoading && state.releases.isEmpty) {
      return const SkeletonList(count: 5);
    }

    if (state.error != null && state.releases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load releases',
            body: state.error!,
            action: FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (state.releases.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No releases yet',
            body:
                'Published GitHub Releases will appear here. Pull down to '
                'refresh once the first one is out.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: state.releases.length + 1,
      itemBuilder: (_, index) => index == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _introduction(context, state),
            )
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ReleaseCard(
                key: ValueKey(
                  state.releases[index - 1].htmlUrl +
                      state.releases[index - 1].tagName,
                ),
                release: state.releases[index - 1],
                isLatest: index == 1,
              ),
            ),
    );
  }

  List<Widget> _introduction(BuildContext context, ChangelogState state) => [
    Text(
      'Release notes',
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 8),
    Text(
      'The latest changes, with earlier versions below.',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    ),
    const SizedBox(height: 24),
    if (state.isLoading && state.releases.isNotEmpty)
      const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LinearProgressIndicator(),
      ),
    if (state.error != null && state.releases.isNotEmpty) ...[
      Text(
        'Could not refresh. Showing previously loaded releases.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      TextButton(onPressed: _refresh, child: const Text('Try again')),
      const SizedBox(height: 16),
    ],
  ];
}
