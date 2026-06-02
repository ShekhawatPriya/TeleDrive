part 'drive_file_models.dart';

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

const _unset = Object();

class DriveState {
  const DriveState({
    this.files = const [],
    this.mediaFiles = const [],
    this.folders = const [],
    this.folderPages = const {},
    this.starred = const DriveStarredCache(),
    this.loading = false,
    this.error,
    this.mediaCursor,
    this.loadingMoreMedia = false,
    this.deleteProgress,
    this.activeFolderId,
    this.trashRevision = 0,
    this.archiveRevision = 0,
    this.lockedRevision = 0,
  });

  /// Flat union of all server files across all loaded folder pages, plus any
  /// optimistic items. Derived view kept in sync by the controller — folder
  /// views must read from [folderPages] instead. Preserved for upload-code
  /// compatibility (it inspects this list to compute settled-server ids).
  final List<DriveFile> files;
  final List<DriveFile> mediaFiles;

  /// Flat list of all folders the controller has seen (root bootstrap, child
  /// listings, mutations). Intentionally incomplete after on-demand loading;
  /// folder views must read from [folderPages].
  final List<DriveFolder> folders;
  final Map<String?, DriveFolderPage> folderPages;
  final DriveStarredCache starred;
  final bool loading;
  final String? error;
  final String? mediaCursor;
  final bool loadingMoreMedia;
  final ({int completed, int failed, int total})? deleteProgress;
  final String? activeFolderId;
  final int trashRevision;
  final int archiveRevision;
  final int lockedRevision;

  DriveState copyWith({
    List<DriveFile>? files,
    List<DriveFile>? mediaFiles,
    List<DriveFolder>? folders,
    Map<String?, DriveFolderPage>? folderPages,
    DriveStarredCache? starred,
    bool? loading,
    String? error,
    Object? mediaCursor = _unset,
    bool? loadingMoreMedia,
    ({int completed, int failed, int total})? deleteProgress,
    bool clearError = false,
    bool clearDeleteProgress = false,
    Object? activeFolderId = _unset,
    int? trashRevision,
    int? archiveRevision,
    int? lockedRevision,
  }) {
    return DriveState(
      files: files ?? this.files,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      folders: folders ?? this.folders,
      folderPages: folderPages ?? this.folderPages,
      starred: starred ?? this.starred,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      mediaCursor: mediaCursor == _unset
          ? this.mediaCursor
          : mediaCursor as String?,
      loadingMoreMedia: loadingMoreMedia ?? this.loadingMoreMedia,
      deleteProgress: clearDeleteProgress
          ? null
          : deleteProgress ?? this.deleteProgress,
      activeFolderId: activeFolderId == _unset
          ? this.activeFolderId
          : activeFolderId as String?,
      trashRevision: trashRevision ?? this.trashRevision,
      archiveRevision: archiveRevision ?? this.archiveRevision,
      lockedRevision: lockedRevision ?? this.lockedRevision,
    );
  }
}

class DriveSnapshot {
  const DriveSnapshot({
    required this.files,
    required this.mediaFiles,
    required this.folders,
    this.mediaCursor,
    this.rootFileCursor,
    this.rootFolderCursor,
  });

  final List<DriveFile> files;
  final List<DriveFile> mediaFiles;
  final List<DriveFolder> folders;
  final String? mediaCursor;
  final String? rootFileCursor;
  final String? rootFolderCursor;
}

/// Per-folder loaded state. The map key in [DriveState.folderPages] is the
/// folder id (or null for root). [loaded] flips to true after the first
/// successful fetch — use it (not list emptiness) to decide between an empty
/// state and a skeleton.
class DriveFolderPage {
  const DriveFolderPage({
    this.files = const [],
    this.subfolders = const [],
    this.fileCursor,
    this.folderCursor,
    this.loaded = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<DriveFile> files;
  final List<DriveFolder> subfolders;
  final String? fileCursor;
  final String? folderCursor;
  final bool loaded;
  final bool loading;
  final bool loadingMore;
  final String? error;

  bool get hasMoreFiles => fileCursor != null;
  bool get hasMoreFolders => folderCursor != null;
  bool get hasMore => hasMoreFiles || hasMoreFolders;

  DriveFolderPage copyWith({
    List<DriveFile>? files,
    List<DriveFolder>? subfolders,
    Object? fileCursor = _unset,
    Object? folderCursor = _unset,
    bool? loaded,
    bool? loading,
    bool? loadingMore,
    Object? error = _unset,
  }) {
    return DriveFolderPage(
      files: files ?? this.files,
      subfolders: subfolders ?? this.subfolders,
      fileCursor: fileCursor == _unset
          ? this.fileCursor
          : fileCursor as String?,
      folderCursor: folderCursor == _unset
          ? this.folderCursor
          : folderCursor as String?,
      loaded: loaded ?? this.loaded,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error == _unset ? this.error : error as String?,
    );
  }
}

/// Server-backed cache of starred files and folders. Kept separate from the
/// folder pages because a starred item may live in a folder that has never
/// been opened locally.
class DriveStarredCache {
  const DriveStarredCache({
    this.files = const [],
    this.folders = const [],
    this.fileCursor,
    this.folderCursor,
    this.loaded = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final List<DriveFile> files;
  final List<DriveFolder> folders;
  final String? fileCursor;
  final String? folderCursor;
  final bool loaded;
  final bool loading;
  final bool loadingMore;
  final String? error;

  bool get hasMoreFiles => fileCursor != null;
  bool get hasMoreFolders => folderCursor != null;
  bool get hasMore => hasMoreFiles || hasMoreFolders;

  DriveStarredCache copyWith({
    List<DriveFile>? files,
    List<DriveFolder>? folders,
    Object? fileCursor = _unset,
    Object? folderCursor = _unset,
    bool? loaded,
    bool? loading,
    bool? loadingMore,
    Object? error = _unset,
  }) {
    return DriveStarredCache(
      files: files ?? this.files,
      folders: folders ?? this.folders,
      fileCursor: fileCursor == _unset
          ? this.fileCursor
          : fileCursor as String?,
      folderCursor: folderCursor == _unset
          ? this.folderCursor
          : folderCursor as String?,
      loaded: loaded ?? this.loaded,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error == _unset ? this.error : error as String?,
    );
  }
}
