part of 'drive_models.dart';

class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.kind,
    required this.size,
    required this.modifiedAt,
    required this.createdAt,
    required this.parentId,
    required this.starred,
    this.shared = false,
    this.mimeType,
    this.uploadStatus,
    this.uploadError,
    this.storageMode = 'client_managed',
    this.uploadOrigin = 'client_tdlib',
    this.publicProxyStatus,
    this.verificationStatus,
    this.mediaAccessMode = 'server_proxy',
    this.originalRefAvailable = false,
    this.thumbnailRefAvailable = false,
    this.previewRefAvailable = false,
    this.thumbnailStatus,
    this.previewStatus,
    this.thumbnailVersion,
    this.previewVersion,
    this.widthPx,
    this.heightPx,
    this.duration,
    this.thumbnailUrl,
    this.previewUrl,
    this.streamUrl,
    this.downloadUrl,
    this.localUri,
    this.lastAccessedAt,
    this.isOptimistic = false,
    this.localId,
  });

  final String id;
  final String name;
  final FileKind kind;
  final int size;
  final String modifiedAt;
  final String createdAt;
  final String? parentId;
  final bool starred;
  final bool shared;
  final String? mimeType;
  final String? uploadStatus;
  final String? uploadError;
  final String storageMode;
  final String uploadOrigin;
  final String? publicProxyStatus;
  final String? verificationStatus;
  final String mediaAccessMode;
  final bool originalRefAvailable;
  final bool thumbnailRefAvailable;
  final bool previewRefAvailable;
  final String? thumbnailStatus;
  final String? previewStatus;
  final int? thumbnailVersion;
  final int? previewVersion;
  final int? widthPx;
  final int? heightPx;
  final int? duration;
  final String? thumbnailUrl;
  final String? previewUrl;
  final String? streamUrl;
  final String? downloadUrl;
  final String? localUri;
  final String? lastAccessedAt;
  final bool isOptimistic;
  final String? localId;

  DriveFile copyWith({
    bool? starred,
    bool? shared,
    String? name,
    Object? parentId = _unset,
    String? uploadStatus,
    String? uploadError,
    String? lastAccessedAt,
    String? localId,
  }) {
    return DriveFile(
      id: id,
      name: name ?? this.name,
      kind: kind,
      size: size,
      modifiedAt: modifiedAt,
      createdAt: createdAt,
      parentId: parentId == _unset ? this.parentId : parentId as String?,
      starred: starred ?? this.starred,
      shared: shared ?? this.shared,
      mimeType: mimeType,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadError: uploadError ?? this.uploadError,
      storageMode: storageMode,
      uploadOrigin: uploadOrigin,
      publicProxyStatus: publicProxyStatus,
      verificationStatus: verificationStatus,
      mediaAccessMode: mediaAccessMode,
      originalRefAvailable: originalRefAvailable,
      thumbnailRefAvailable: thumbnailRefAvailable,
      previewRefAvailable: previewRefAvailable,
      thumbnailStatus: thumbnailStatus,
      previewStatus: previewStatus,
      thumbnailVersion: thumbnailVersion,
      previewVersion: previewVersion,
      widthPx: widthPx,
      heightPx: heightPx,
      duration: duration,
      thumbnailUrl: thumbnailUrl,
      previewUrl: previewUrl,
      streamUrl: streamUrl,
      downloadUrl: downloadUrl,
      localUri: localUri,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      isOptimistic: isOptimistic,
      localId: localId ?? this.localId,
    );
  }
}

class DriveFolder {
  const DriveFolder({
    required this.id,
    required this.name,
    required this.parentId,
    required this.modifiedAt,
    required this.createdAt,
    this.starred = false,
    this.shared = false,
    this.recursiveFileCount = 0,
    this.recursiveSize = 0,
    this.isOptimistic = false,
    this.uploadError,
  });

  final String id;
  final String name;
  final String? parentId;
  final String modifiedAt;
  final String createdAt;
  final bool starred;
  final bool shared;
  final int recursiveFileCount;
  final int recursiveSize;
  final bool isOptimistic;
  final String? uploadError;

  DriveFolder copyWith({
    String? name,
    Object? parentId = _unset,
    bool? starred,
    bool? shared,
    int? recursiveFileCount,
    int? recursiveSize,
    bool? isOptimistic,
    String? uploadError,
    bool clearUploadError = false,
  }) => DriveFolder(
    id: id,
    name: name ?? this.name,
    parentId: parentId == _unset ? this.parentId : parentId as String?,
    modifiedAt: modifiedAt,
    createdAt: createdAt,
    starred: starred ?? this.starred,
    shared: shared ?? this.shared,
    recursiveFileCount: recursiveFileCount ?? this.recursiveFileCount,
    recursiveSize: recursiveSize ?? this.recursiveSize,
    isOptimistic: isOptimistic ?? this.isOptimistic,
    uploadError: clearUploadError ? null : uploadError ?? this.uploadError,
  );
}
