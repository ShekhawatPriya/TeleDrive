enum FileKind {
  folder,
  pdf,
  image,
  video,
  doc,
  sheet,
  slides,
  audio,
  zip,
  code,
  text,
  other,
}

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

  DriveFile copyWith({
    bool? starred,
    String? name,
    String? uploadStatus,
    String? uploadError,
    String? lastAccessedAt,
  }) {
    return DriveFile(
      id: id,
      name: name ?? this.name,
      kind: kind,
      size: size,
      modifiedAt: modifiedAt,
      createdAt: createdAt,
      parentId: parentId,
      starred: starred ?? this.starred,
      shared: shared,
      mimeType: mimeType,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadError: uploadError ?? this.uploadError,
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

  DriveFolder copyWith({
    String? name,
    bool? starred,
    int? recursiveFileCount,
    int? recursiveSize,
  }) => DriveFolder(
    id: id,
    name: name ?? this.name,
    parentId: parentId,
    modifiedAt: modifiedAt,
    createdAt: createdAt,
    starred: starred ?? this.starred,
    shared: shared,
    recursiveFileCount: recursiveFileCount ?? this.recursiveFileCount,
    recursiveSize: recursiveSize ?? this.recursiveSize,
  );
}

class DriveState {
  const DriveState({
    this.files = const [],
    this.mediaFiles = const [],
    this.folders = const [],
    this.loading = false,
    this.error,
    this.mediaCursor,
    this.loadingMoreMedia = false,
    this.deleteProgress,
  });

  final List<DriveFile> files;
  final List<DriveFile> mediaFiles;
  final List<DriveFolder> folders;
  final bool loading;
  final String? error;
  final String? mediaCursor;
  final bool loadingMoreMedia;
  final ({int completed, int failed, int total})? deleteProgress;

  int get usedStorage => files
      .where((f) => f.uploadStatus == null || f.uploadStatus == 'available')
      .fold(0, (sum, f) => sum + f.size);
  int get totalStorage => 50000000000;

  DriveState copyWith({
    List<DriveFile>? files,
    List<DriveFile>? mediaFiles,
    List<DriveFolder>? folders,
    bool? loading,
    String? error,
    String? mediaCursor,
    bool? loadingMoreMedia,
    ({int completed, int failed, int total})? deleteProgress,
    bool clearError = false,
    bool clearDeleteProgress = false,
  }) {
    return DriveState(
      files: files ?? this.files,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      folders: folders ?? this.folders,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      mediaCursor: mediaCursor ?? this.mediaCursor,
      loadingMoreMedia: loadingMoreMedia ?? this.loadingMoreMedia,
      deleteProgress: clearDeleteProgress
          ? null
          : deleteProgress ?? this.deleteProgress,
    );
  }
}
