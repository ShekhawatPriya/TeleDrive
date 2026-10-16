part of 'changelog_screen.dart';

/// iOS What's New and version pages, composed like Apple's own release
/// surfaces: a centered hero card for the version, then each published
/// section as an inset group on the grouped canvas. Nothing sits in a leading
/// icon gutter, so notes use the full card width on a narrow phone. A bold
/// lead in a note (`**Photos:** …`) becomes a small tinted tag above its text;
/// GitHub's generated pull-request and contributor lines become tappable rows
/// with `#12` tags instead of raw URLs. Headings and notes are the author's;
/// symbols are chosen from their words and never add content.
class _IosChangelog extends StatelessWidget {
  const _IosChangelog({required this.state, required this.onRefresh});

  final ChangelogState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final releases = state.releases;
    return IosPage(
      title: 'What’s New',
      compact: true,
      hero: false,
      onRefresh: onRefresh,
      children: [
        if (state.isLoading && releases.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CupertinoActivityIndicator(),
          )
        else if (releases.isEmpty)
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
                onTap: onRefresh,
              ),
            ],
          )
        else ...[
          if (state.error != null)
            IosGroup(
              footer: 'Could not refresh. Showing previously loaded releases.',
              children: [
                IosRow(
                  title: 'Try Again',
                  action: true,
                  trailing: const SizedBox.shrink(),
                  onTap: onRefresh,
                ),
              ],
            ),
          _IosReleaseDetail(release: releases.first, latest: true),
          if (releases.length > 1)
            IosGroup(
              title: 'Previous Versions',
              children: [
                for (final release in releases.skip(1))
                  IosRow(
                    title: _versionLabel(release),
                    subtitle: _summary(release),
                    value: release.publishedAt == null
                        ? null
                        : DateFormat.yMMMd().format(
                            release.publishedAt!.toLocal(),
                          ),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => IosPage(
                          title: _versionLabel(release),
                          compact: true,
                          hero: true,
                          children: [_IosReleaseDetail(release: release)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

String _versionLabel(GithubRelease release) {
  final tag = release.tagName.replaceFirst(RegExp(r'^v'), '');
  return tag.isEmpty ? release.title : 'Version $tag';
}

/// The author's title when it differs from the version, else the first note.
String _summary(GithubRelease release) {
  final title = release.title.trim();
  if (title.isNotEmpty && title != release.tagName) return title;
  final preview = ReleaseNotes(release.body).preview;
  if (preview.length <= 84) return preview;
  final cut = preview.lastIndexOf(' ', 84);
  return '${preview.substring(0, cut > 40 ? cut : 84).trimRight()}…';
}

void _openReleaseLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// One release: the hero card, the published sections as groups, then the
/// comparison, the GitHub page and the technical notes.
class _IosReleaseDetail extends StatefulWidget {
  const _IosReleaseDetail({required this.release, this.latest = false});
  final GithubRelease release;
  final bool latest;

  @override
  State<_IosReleaseDetail> createState() => _IosReleaseDetailState();
}

class _IosReleaseDetailState extends State<_IosReleaseDetail> {
  bool _showTechnical = false;

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final notes = ReleaseNotes(release.body);
    final scheme = Theme.of(context).colorScheme;
    final published = notes.sections.where((s) => !s.isTechnical).toList();
    final technical = notes.sections.where((s) => s.isTechnical).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IosReleaseHero(release: release, latest: widget.latest),
        if (published.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Text(
              notes.comparisonLinks.isEmpty
                  ? 'No detailed notes were published for this release.'
                  : 'This release includes a code comparison. Detailed app changes were not published.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final section in published) _IosReleaseSection(section: section),
        if (technical.isNotEmpty ||
            notes.comparisonLinks.isNotEmpty ||
            release.htmlUrl.isNotEmpty)
          IosGroup(
            title: 'More',
            children: [
              for (final url in notes.comparisonLinks)
                IosRow(
                  title: 'Compare Changes',
                  subtitle: compareRange(url),
                  icon: CupertinoIcons.arrow_right_arrow_left,
                  color: IosTint.neutral,
                  trailing: const _ExternalMark(),
                  onTap: () => _openReleaseLink(url),
                ),
              if (release.htmlUrl.isNotEmpty)
                IosRow(
                  title: 'View on GitHub',
                  icon: CupertinoIcons.globe,
                  color: IosTint.neutral,
                  trailing: const _ExternalMark(),
                  onTap: () => _openReleaseLink(release.htmlUrl),
                ),
              if (technical.isNotEmpty)
                Semantics(
                  expanded: _showTechnical,
                  child: IosRow(
                    title: 'Build & Documentation',
                    icon: CupertinoIcons.hammer_fill,
                    color: IosTint.neutral,
                    trailing: AnimatedRotation(
                      turns: _showTechnical ? .5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () =>
                        setState(() => _showTechnical = !_showTechnical),
                  ),
                ),
              if (_showTechnical)
                for (final section in technical)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _MarkdownBody(text: section.body),
                      ],
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}

/// The version as a Settings-style hero card: the app icon, the version (or
/// the author's title) and when it was published, with a Latest or
/// Pre-release tag.
class _IosReleaseHero extends StatelessWidget {
  const _IosReleaseHero({required this.release, required this.latest});
  final GithubRelease release;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = _versionLabel(release);
    final custom =
        release.title.trim().isNotEmpty && release.title != release.tagName;
    final title = custom ? release.title.trim() : version;
    final date = release.publishedAt == null
        ? null
        : DateFormat.yMMMMd().format(release.publishedAt!.toLocal());
    final detail = [if (custom) version, ?date].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: IosPageMetrics.groupSpacing),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(IosPageMetrics.groupRadius),
        child: ColoredBox(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    key: IosHeroScope.titleKeyOf(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: -.2,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                if (latest || release.isPrerelease) ...[
                  const SizedBox(height: 14),
                  release.isPrerelease
                      ? const _Tag(
                          label: 'Pre-release',
                          icon: CupertinoIcons.hammer_fill,
                          color: CupertinoColors.systemOrange,
                        )
                      : const _Tag(
                          label: 'Latest Release',
                          icon: CupertinoIcons.checkmark_seal_fill,
                          color: CupertinoColors.systemBlue,
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A published section as one inset group, its heading outside the card.
class _IosReleaseSection extends StatelessWidget {
  const _IosReleaseSection({required this.section});
  final ReleaseNotesSection section;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    switch (section.kind) {
      case ReleaseSectionKind.changes:
        final items = section.items;
        final changes = section.changes;
        for (var i = 0; i < items.length; i++) {
          final change = changes[i];
          rows.add(
            change == null
                ? _NoteRow(note: ReleaseHighlight.parse(items[i]))
                : _ChangeRow(change: change),
          );
        }
      case ReleaseSectionKind.contributors:
        final items = section.items;
        final people = section.contributors;
        for (var i = 0; i < items.length; i++) {
          final person = people[i];
          rows.add(
            person == null
                ? _NoteRow(note: ReleaseHighlight.parse(items[i]))
                : _ContributorRow(contributor: person),
          );
        }
      case ReleaseSectionKind.notes:
      case ReleaseSectionKind.technical:
        for (final note in section.highlights) {
          rows.add(_NoteRow(note: note));
        }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final (icon, color) = _releaseSymbol(section.title, section.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: IosPageMetrics.groupSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.title.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
              child: Semantics(
                header: true,
                child: Row(
                  children: [
                    Icon(icon, size: 17, color: color.resolveFrom(context)),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IosGroup(bottomSpacing: 0, children: rows),
        ],
      ),
    );
  }
}

/// A note: the author's bold lead as a tinted tag, then the note itself.
class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});
  final ReleaseHighlight note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = note.label;
    final (icon, color) = label == null
        ? (null, null)
        : _releaseSymbol(label, ReleaseSectionKind.notes);
    // Full width, so a short note starts at the margin instead of centering.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            _Tag(label: label, icon: icon, color: color!),
            const SizedBox(height: 9),
          ],
          _InlineText(
            text: note.text,
            baseStyle: TextStyle(
              fontSize: 16,
              height: 1.42,
              letterSpacing: -.3,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// A merged pull request GitHub listed under What's Changed.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});
  final ReleaseChange change;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final number = change.number;
    return _PressableRow(
      semanticLabel: [
        change.title,
        if (number != null) 'pull request $number',
        if (change.author != null) 'by ${change.author}',
      ].join(', '),
      onTap: () => _openReleaseLink(change.url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            change.title,
            style: TextStyle(
              fontSize: 16,
              height: 1.38,
              letterSpacing: -.3,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (number != null)
                _Tag(
                  label: '#$number',
                  icon: CupertinoIcons.arrow_merge,
                  color: CupertinoColors.systemPurple,
                  monospaced: true,
                ),
              if (change.author != null)
                Text(
                  '@${change.author}',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: -.1,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Someone GitHub listed under New Contributors.
class _ContributorRow extends StatelessWidget {
  const _ContributorRow({required this.contributor});
  final ReleaseContributor contributor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final number = contributor.number;
    final tint = CupertinoColors.systemGreen.resolveFrom(context);
    return _PressableRow(
      semanticLabel:
          '@${contributor.handle}, first contribution'
          '${number == null ? '' : ' in pull request $number'}',
      onTap: () => _openReleaseLink(contributor.url),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: .16),
              ),
              child: Text(
                contributor.handle.characters.first.toUpperCase(),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: tint,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${contributor.handle}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const _Tag(
                      label: 'First Contribution',
                      icon: CupertinoIcons.star_fill,
                      color: CupertinoColors.systemGreen,
                    ),
                    if (number != null)
                      _Tag(
                        label: '#$number',
                        color: CupertinoColors.systemGrey,
                        monospaced: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable card row that highlights while pressed, as a table cell does,
/// with an external-link mark at the trailing edge.
class _PressableRow extends StatefulWidget {
  const _PressableRow({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
  });
  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final highlight = CupertinoColors.systemFill.resolveFrom(context);
    return Semantics(
      button: true,
      link: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapCancel: () => _press(false),
        onTapUp: (_) => _press(false),
        onTap: widget.onTap,
        child: ColoredBox(
          color: _pressed ? highlight : Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: IosPageMetrics.rowMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 14, 14),
              child: Row(
                children: [
                  Expanded(child: widget.child),
                  const SizedBox(width: 12),
                  const _ExternalMark(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExternalMark extends StatelessWidget {
  const _ExternalMark();
  @override
  Widget build(BuildContext context) => Icon(
    CupertinoIcons.arrow_up_right,
    size: 14,
    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
  );
}

/// A small tinted capsule: a category, a state or a pull-request number.
class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
    this.icon,
    this.monospaced = false,
  });
  final String label;
  final IconData? icon;
  final Color color;
  final bool monospaced;

  @override
  Widget build(BuildContext context) {
    final tint = CupertinoDynamicColor.resolve(color, context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tint.withValues(alpha: dark ? .22 : .12),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(icon == null ? 9 : 8, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: tint),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: monospaced ? 0 : -.1,
                  fontFamily: monospaced ? 'JetBrains Mono' : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A symbol and system tint chosen from a heading's or label's words.
(IconData, CupertinoDynamicColor) _releaseSymbol(
  String title,
  ReleaseSectionKind kind,
) {
  switch (kind) {
    case ReleaseSectionKind.changes:
      return (CupertinoIcons.arrow_merge, CupertinoColors.systemPurple);
    case ReleaseSectionKind.contributors:
      return (CupertinoIcons.person_2_fill, CupertinoColors.systemGreen);
    case ReleaseSectionKind.technical:
      return (CupertinoIcons.hammer_fill, CupertinoColors.systemGrey);
    case ReleaseSectionKind.notes:
      break;
  }
  final t = title.toLowerCase();
  bool has(List<String> words) => words.any(t.contains);
  if (has(['highlight', "what's new", 'feature'])) {
    return (CupertinoIcons.sparkles, CupertinoColors.systemBlue);
  }
  if (has(['folder', 'drive', 'file', 'brows', 'recovery', 'starred'])) {
    return (CupertinoIcons.folder_fill, CupertinoColors.systemBlue);
  }
  if (has(['share', 'sharing', 'link'])) {
    return (CupertinoIcons.square_arrow_up, CupertinoColors.systemBlue);
  }
  if (has(['photo', 'gallery', 'image', 'library'])) {
    return (CupertinoIcons.photo_on_rectangle, CupertinoColors.systemPink);
  }
  if (has(['video', 'player'])) {
    return (CupertinoIcons.play_rectangle_fill, CupertinoColors.systemOrange);
  }
  if (has(['upload', 'backup', 'transfer', 'sync'])) {
    return (CupertinoIcons.cloud_upload_fill, CupertinoColors.systemIndigo);
  }
  if (has(['download', 'cache', 'storage'])) {
    return (CupertinoIcons.arrow_down_circle_fill, CupertinoColors.systemTeal);
  }
  if (has(['search'])) {
    return (CupertinoIcons.search, CupertinoColors.systemBlue);
  }
  if (has(['security', 'privacy', 'session', 'auth'])) {
    return (CupertinoIcons.lock_shield_fill, CupertinoColors.systemGreen);
  }
  if (has(['account', 'login', 'sign', 'profile', 'telegram'])) {
    return (
      CupertinoIcons.person_crop_circle_fill,
      CupertinoColors.systemIndigo,
    );
  }
  if (has(['performance', 'speed', 'faster', 'smooth'])) {
    return (CupertinoIcons.speedometer, CupertinoColors.systemOrange);
  }
  if (has(['fix', 'bug', 'stability', 'reliab'])) {
    return (CupertinoIcons.wrench_fill, CupertinoColors.systemGrey);
  }
  if (has(['ios', 'iphone', 'android', 'platform'])) {
    return (CupertinoIcons.device_phone_portrait, CupertinoColors.systemGrey);
  }
  if (has(['design', 'look', 'interface', 'theme', 'appearance', 'control'])) {
    return (CupertinoIcons.paintbrush_fill, CupertinoColors.systemPurple);
  }
  if (has(['about', 'release', 'changelog', 'documentation'])) {
    return (CupertinoIcons.info_circle_fill, CupertinoColors.systemGrey);
  }
  if (has(['setting'])) {
    return (CupertinoIcons.gear_solid, CupertinoColors.systemGrey);
  }
  if (has(['notification', 'alert'])) {
    return (CupertinoIcons.bell_fill, CupertinoColors.systemRed);
  }
  return (CupertinoIcons.sparkles, CupertinoColors.systemBlue);
}
