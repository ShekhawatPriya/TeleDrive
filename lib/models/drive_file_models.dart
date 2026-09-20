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
    this.storageMode,
    this.uploadOrigin = 'client_tdlib',
    this.publicProxyStatus,
    this.verificationStatus,
    this.mediaAccessMode,
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

  /// Server record revision, also changed by metadata actions. Used by caches;
  /// never use this as a photo's upload/capture date.
  final String modifiedAt;

  /// Immutable upload/creation timestamp. This is not an EXIF capture date.
  final String createdAt;
  final String? parentId;
  final bool starred;
  final bool shared;
  final String? mimeType;
  final String? uploadStatus;
  final String? uploadError;
  final String? storageMode;
  final String uploadOrigin;
  final String? publicProxyStatus;
  final String? verificationStatus;
  final String? mediaAccessMode;
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

  bool get isClientManaged =>
      storageMode == 'client_managed' ||
      mediaAccessMode == 'client_direct' ||
      mediaAccessMode == 'client_tdlib' ||
      mediaAccessMode == 'telegram_client_direct';

  bool get hasTelegramMediaRefs =>
      originalRefAvailable || thumbnailRefAvailable || previewRefAvailable;

  DriveFile copyWith({
    bool? starred,
    bool? shared,
    String? name,
    Object? parentId = _unset,
    String? mimeType,
    String? uploadStatus,
    String? uploadError,
    Object? storageMode = _unset,
    String? uploadOrigin,
    Object? publicProxyStatus = _unset,
    Object? verificationStatus = _unset,
    Object? mediaAccessMode = _unset,
    bool? originalRefAvailable,
    bool? thumbnailRefAvailable,
    bool? previewRefAvailable,
    Object? thumbnailStatus = _unset,
    Object? previewStatus = _unset,
    Object? thumbnailVersion = _unset,
    Object? previewVersion = _unset,
    Object? widthPx = _unset,
    Object? heightPx = _unset,
    Object? duration = _unset,
    Object? thumbnailUrl = _unset,
    Object? previewUrl = _unset,
    Object? streamUrl = _unset,
    Object? downloadUrl = _unset,
    Object? localUri = _unset,
    String? lastAccessedAt,
    bool? isOptimistic,
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
      mimeType: mimeType ?? this.mimeType,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadError: uploadError ?? this.uploadError,
      storageMode: storageMode == _unset
          ? this.storageMode
          : storageMode as String?,
      uploadOrigin: uploadOrigin ?? this.uploadOrigin,
      publicProxyStatus: publicProxyStatus == _unset
          ? this.publicProxyStatus
          : publicProxyStatus as String?,
      verificationStatus: verificationStatus == _unset
          ? this.verificationStatus
          : verificationStatus as String?,
      mediaAccessMode: mediaAccessMode == _unset
          ? this.mediaAccessMode
          : mediaAccessMode as String?,
      originalRefAvailable: originalRefAvailable ?? this.originalRefAvailable,
      thumbnailRefAvailable:
          thumbnailRefAvailable ?? this.thumbnailRefAvailable,
      previewRefAvailable: previewRefAvailable ?? this.previewRefAvailable,
      thumbnailStatus: thumbnailStatus == _unset
          ? this.thumbnailStatus
          : thumbnailStatus as String?,
      previewStatus: previewStatus == _unset
          ? this.previewStatus
          : previewStatus as String?,
      thumbnailVersion: thumbnailVersion == _unset
          ? this.thumbnailVersion
          : thumbnailVersion as int?,
      previewVersion: previewVersion == _unset
          ? this.previewVersion
          : previewVersion as int?,
      widthPx: widthPx == _unset ? this.widthPx : widthPx as int?,
      heightPx: heightPx == _unset ? this.heightPx : heightPx as int?,
      duration: duration == _unset ? this.duration : duration as int?,
      thumbnailUrl: thumbnailUrl == _unset
          ? this.thumbnailUrl
          : thumbnailUrl as String?,
      previewUrl: previewUrl == _unset
          ? this.previewUrl
          : previewUrl as String?,
      streamUrl: streamUrl == _unset ? this.streamUrl : streamUrl as String?,
      downloadUrl: downloadUrl == _unset
          ? this.downloadUrl
          : downloadUrl as String?,
      localUri: localUri == _unset ? this.localUri : localUri as String?,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      isOptimistic: isOptimistic ?? this.isOptimistic,
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
