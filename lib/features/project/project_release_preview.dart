part of 'project_screen.dart';

/// A readable preview of live GitHub release data, with explicit loading,
/// empty and retry states. The installed version remains in the app header.
class _ProjectReleasePreview extends StatelessWidget {
  const _ProjectReleasePreview({required this.state, required this.onRetry});
  final ChangelogState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    final release = state.latest;
    final ios = theme.platform == TargetPlatform.iOS;
    final title = release == null
        ? state.isLoading
              ? 'Loading release notes…'
              : state.error != null
              ? 'Release notes unavailable'
              : 'No published releases yet'
        : release.displayTitle;
    final published = release?.publishedAt;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What’s New',
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (published != null) ...[
            const SizedBox(height: 4),
            Text(
              '${DateFormat.yMMMd().format(published.toLocal())}${release!.isPrerelease ? ' · Pre-release' : ''}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            release != null
                ? _summary(release)
                : state.error ??
                      (state.isLoading
                          ? 'Fetching published releases from GitHub.'
                          : 'Published GitHub releases will appear here.'),
            style: text.bodyMedium?.copyWith(
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (ios)
            CupertinoButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              onPressed: state.error != null && release == null
                  ? onRetry
                  : () => context.push('/settings/project/changelog'),
              child: Text(
                state.error != null && release == null
                    ? 'Try Again'
                    : 'View Release History',
                style: text.bodyMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: state.error != null && release == null
                    ? onRetry
                    : () => context.push('/settings/project/changelog'),
                child: Text(
                  state.error != null && release == null
                      ? 'Try again'
                      : 'View release history',
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _summary(GithubRelease release) {
    final lines = release.body
        .split('\n')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.contains('https://') &&
              !line.contains('http://'),
        )
        .take(2)
        .map(
          (line) => line
              .replaceFirst(RegExp(r'^[-*+]\s+'), '')
              .replaceAll('**', '')
              .replaceAll('`', ''),
        )
        .toList();
    if (lines.isNotEmpty) return lines.join('\n');
    return release.body.contains('/compare/')
        ? 'The full changelog for this release is available on GitHub.'
        : 'Open the release history for published notes and downloads.';
  }
}
