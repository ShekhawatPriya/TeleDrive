// Models for the GitHub Releases REST API.
//
// See https://docs.github.com/rest/releases/releases#list-releases.
// Parsing is intentionally defensive: GitHub's payload is external, untrusted
// input, so every field is coerced and bad entries are skipped rather than
// thrown on.

class GithubReleaseAsset {
  const GithubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    this.size = 0,
    this.contentType,
    this.downloadCount = 0,
  });

  final String name;
  final String downloadUrl;
  final int size;
  final String? contentType;
  final int downloadCount;

  bool get isApk =>
      name.toLowerCase().endsWith('.apk') ||
      contentType == 'application/vnd.android.package-archive';

  static GithubReleaseAsset? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final urlRaw = raw['browser_download_url'];
    if (urlRaw is! String || urlRaw.trim().isEmpty) return null;
    final uri = Uri.tryParse(urlRaw.trim());
    if (uri == null || !uri.hasScheme) return null;

    final nameRaw = raw['name'];
    return GithubReleaseAsset(
      name: nameRaw is String && nameRaw.trim().isNotEmpty
          ? nameRaw.trim()
          : uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'asset',
      downloadUrl: urlRaw.trim(),
      size: _asInt(raw['size']) ?? 0,
      contentType: raw['content_type'] is String
          ? (raw['content_type'] as String).trim()
          : null,
      downloadCount: _asInt(raw['download_count']) ?? 0,
    );
  }
}

class GithubRelease {
  const GithubRelease({
    required this.tagName,
    required this.title,
    required this.body,
    required this.htmlUrl,
    this.publishedAt,
    this.isPrerelease = false,
    this.isDraft = false,
    this.assets = const [],
  });

  final String tagName;
  final String title;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final bool isPrerelease;
  final bool isDraft;
  final List<GithubReleaseAsset> assets;

  /// A human-friendly display name, falling back to the tag when GitHub's
  /// `name` field is empty (common for tag-only releases).
  String get displayTitle => title.isNotEmpty ? title : tagName;

  GithubReleaseAsset? get apkAsset {
    for (final asset in assets) {
      if (asset.isApk) return asset;
    }
    return null;
  }

  static GithubRelease? tryParse(Object? raw) {
    if (raw is! Map) return null;

    final tagRaw = raw['tag_name'];
    final tagName = tagRaw is String ? tagRaw.trim() : '';

    final nameRaw = raw['name'];
    final title = nameRaw is String ? nameRaw.trim() : '';

    // A release with neither a tag nor a name is not useful to display.
    if (tagName.isEmpty && title.isEmpty) return null;

    final htmlRaw = raw['html_url'];
    final htmlUrl = htmlRaw is String ? htmlRaw.trim() : '';

    final bodyRaw = raw['body'];
    final body = bodyRaw is String ? bodyRaw.trim() : '';

    DateTime? publishedAt;
    final publishedRaw = raw['published_at'];
    if (publishedRaw is String && publishedRaw.trim().isNotEmpty) {
      publishedAt = DateTime.tryParse(publishedRaw.trim())?.toUtc();
    }

    final assets = <GithubReleaseAsset>[];
    final assetsRaw = raw['assets'];
    if (assetsRaw is List) {
      for (final entry in assetsRaw) {
        final asset = GithubReleaseAsset.tryParse(entry);
        if (asset != null) assets.add(asset);
      }
    }

    return GithubRelease(
      tagName: tagName,
      title: title,
      body: body,
      htmlUrl: htmlUrl,
      publishedAt: publishedAt,
      isPrerelease: raw['prerelease'] == true,
      isDraft: raw['draft'] == true,
      assets: assets,
    );
  }

  /// Parses the top-level array returned by the list-releases endpoint,
  /// dropping drafts and any entries that fail to parse.
  static List<GithubRelease> parseList(Object? raw) {
    if (raw is! List) return const [];
    final releases = <GithubRelease>[];
    for (final entry in raw) {
      final release = GithubRelease.tryParse(entry);
      if (release != null && !release.isDraft) releases.add(release);
    }
    return releases;
  }
}

int? _asInt(Object? value) {
  return switch (value) {
    int v => v,
    String v => int.tryParse(v.trim()),
    num v => v.toInt(),
    _ => null,
  };
}
