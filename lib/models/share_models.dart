import 'drive_models.dart';

enum SharePermission { preview, download }

extension SharePermissionX on SharePermission {
  String get apiValue => switch (this) {
    SharePermission.preview => 'preview',
    SharePermission.download => 'download',
  };

  String get label => switch (this) {
    SharePermission.preview => 'Preview only',
    SharePermission.download => 'Allow download',
  };

  static SharePermission fromApi(String value) =>
      value == 'download' ? SharePermission.download : SharePermission.preview;
}

enum ShareItemType { file, folder }

extension ShareItemTypeX on ShareItemType {
  String get apiValue => switch (this) {
    ShareItemType.file => 'file',
    ShareItemType.folder => 'folder',
  };

  static ShareItemType fromApi(String value) =>
      value == 'folder' ? ShareItemType.folder : ShareItemType.file;
}

enum FolderShareMode { snapshot, live }

extension FolderShareModeX on FolderShareMode {
  String get apiValue => switch (this) {
    FolderShareMode.snapshot => 'snapshot',
    FolderShareMode.live => 'live',
  };
}

class ShareItemRequest {
  const ShareItemRequest({required this.type, required this.id, this.mode});

  final ShareItemType type;
  final String id;
  final FolderShareMode? mode;

  Map<String, dynamic> toJson() => {
    'type': type.apiValue,
    'id': int.parse(id),
    if (mode != null) 'mode': mode!.apiValue,
  };
}

class ShareItemSummary {
  const ShareItemSummary({
    required this.publicId,
    required this.kind,
    required this.name,
    required this.relativePath,
    this.fileId,
    this.folderId,
    this.thumbnailUrl,
    this.previewUrl,
    this.downloadUrl,
  });

  final String publicId;
  final ShareItemType kind;
  final String name;
  final String relativePath;
  final String? fileId;
  final String? folderId;
  final String? thumbnailUrl;
  final String? previewUrl;
  final String? downloadUrl;

  FileKind get fileKind => kind == ShareItemType.folder
      ? FileKind.folder
      : FileKind.other;

  factory ShareItemSummary.fromJson(Map<String, dynamic> json) {
    return ShareItemSummary(
      publicId: '${json['publicId']}',
      kind: ShareItemTypeX.fromApi('${json['kind']}'),
      name: '${json['name'] ?? ''}',
      relativePath: '${json['relativePath'] ?? ''}',
      fileId: json['fileId'] == null ? null : '${json['fileId']}',
      folderId: json['folderId'] == null ? null : '${json['folderId']}',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      previewUrl: json['previewUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
    );
  }
}

class Share {
  const Share({
    required this.id,
    required this.token,
    required this.url,
    required this.permission,
    required this.createdAt,
    required this.viewCount,
    required this.downloadCount,
    required this.items,
    this.expiresAt,
    this.revokedAt,
    this.lastAccessedAt,
    this.coverThumbnailUrl,
    this.primaryName,
    this.itemCount,
  });

  final String id;
  final String token;
  final String url;
  final SharePermission permission;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime createdAt;
  final int viewCount;
  final int downloadCount;
  final DateTime? lastAccessedAt;
  final List<ShareItemSummary> items;
  final String? coverThumbnailUrl;
  final String? primaryName;
  final int? itemCount;

  factory Share.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return Share(
      id: '${json['id']}',
      token: '${json['token']}',
      url: '${json['url']}',
      permission: SharePermissionX.fromApi('${json['permission']}'),
      expiresAt: _parseDate(json['expiresAt']),
      revokedAt: _parseDate(json['revokedAt']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      lastAccessedAt: _parseDate(json['lastAccessedAt']),
      items: rawItems
          .map((e) => ShareItemSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      coverThumbnailUrl: json['coverThumbnailUrl'] as String?,
      primaryName: json['primaryName'] as String?,
      itemCount: (json['itemCount'] as num?)?.toInt(),
    );
  }

  factory Share.fromListJson(Map<String, dynamic> json) {
    return Share(
      id: '${json['id']}',
      token: '${json['token']}',
      url: '${json['url']}',
      permission: SharePermissionX.fromApi('${json['permission']}'),
      expiresAt: _parseDate(json['expiresAt']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      lastAccessedAt: _parseDate(json['lastAccessedAt']),
      items: const [],
      coverThumbnailUrl: json['coverThumbnailUrl'] as String?,
      primaryName: '${json['primaryName'] ?? 'Untitled'}',
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isRevoked => revokedAt != null;
  bool get isActive => !isExpired && !isRevoked;
}

class ShareAccess {
  const ShareAccess({
    required this.accessedAt,
    required this.action,
    required this.userAgent,
    required this.isBot,
    this.country,
    this.itemName,
  });

  final DateTime accessedAt;
  final String action;
  final String userAgent;
  final bool isBot;
  final String? country;
  final String? itemName;

  factory ShareAccess.fromJson(Map<String, dynamic> json) => ShareAccess(
    accessedAt: _parseDate(json['accessedAt']) ?? DateTime.now(),
    action: '${json['action']}',
    userAgent: '${json['userAgent'] ?? ''}',
    isBot: json['isBot'] == true,
    country: json['country'] as String?,
    itemName: json['itemName'] as String?,
  );
}

class ShareStats {
  const ShareStats({
    required this.uniqueViewers,
    required this.byCountry,
    required this.timeline,
  });

  final int uniqueViewers;
  final Map<String, int> byCountry;
  final List<ShareTimelineBucket> timeline;

  factory ShareStats.fromJson(Map<String, dynamic> json) {
    final country = (json['byCountry'] as Map?)?.cast<String, dynamic>() ?? {};
    final tl = (json['timeline'] as List?) ?? const [];
    return ShareStats(
      uniqueViewers: (json['uniqueViewers'] as num?)?.toInt() ?? 0,
      byCountry: country.map((k, v) => MapEntry(k, (v as num).toInt())),
      timeline: tl
          .map(
            (e) => ShareTimelineBucket.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class ShareTimelineBucket {
  const ShareTimelineBucket({
    required this.bucket,
    required this.views,
    required this.downloads,
  });

  final DateTime bucket;
  final int views;
  final int downloads;

  factory ShareTimelineBucket.fromJson(Map<String, dynamic> json) =>
      ShareTimelineBucket(
        bucket: _parseDate(json['bucket']) ?? DateTime.now(),
        views: (json['views'] as num?)?.toInt() ?? 0,
        downloads: (json['downloads'] as num?)?.toInt() ?? 0,
      );
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse('$raw');
}
