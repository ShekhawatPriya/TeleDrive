part of '../drive_controller.dart';

class DriveFolderViewSnapshot {
  const DriveFolderViewSnapshot({
    required this.folderId,
    required this.folder,
    required this.folders,
    required this.files,
    required this.path,
    required this.loaded,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
  });

  final String? folderId;
  final DriveFolder? folder;
  final List<DriveFolder> folders;
  final List<DriveFile> files;
  final List<DriveFolder> path;
  final bool loaded;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DriveFolderViewSnapshot) return false;
    if (other.folderId != folderId) return false;
    if (other.folder != folder) return false;
    if (other.loaded != loaded) return false;
    if (other.loading != loading) return false;
    if (other.loadingMore != loadingMore) return false;
    if (other.hasMore != hasMore) return false;
    if (other.error != error) return false;
    if (!identical(other.folders, folders)) return false;
    if (!identical(other.files, files)) return false;
    if (other.path.length != path.length) return false;
    for (var i = 0; i < path.length; i++) {
      if (other.path[i].id != path[i].id ||
          other.path[i].name != path[i].name ||
          other.path[i].parentId != path[i].parentId) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    folderId,
    folder,
    identityHashCode(folders),
    identityHashCode(files),
    loaded,
    loading,
    loadingMore,
    hasMore,
    error,
    path.length,
  );
}

class DriveStarredSnapshot {
  const DriveStarredSnapshot({
    required this.files,
    required this.folders,
    required this.loaded,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
  });

  final List<DriveFile> files;
  final List<DriveFolder> folders;
  final bool loaded;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DriveStarredSnapshot) return false;
    if (other.loaded != loaded ||
        other.loading != loading ||
        other.loadingMore != loadingMore ||
        other.hasMore != hasMore ||
        other.error != error) {
      return false;
    }
    return identical(other.files, files) && identical(other.folders, folders);
  }

  @override
  int get hashCode => Object.hash(
    identityHashCode(files),
    identityHashCode(folders),
    loaded,
    loading,
    loadingMore,
    hasMore,
    error,
  );
}

class DriveRecentsSnapshot {
  const DriveRecentsSnapshot(this.files);
  final List<DriveFile> files;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DriveRecentsSnapshot) return false;
    if (other.files.length != files.length) return false;
    for (var i = 0; i < files.length; i++) {
      if (other.files[i].id != files[i].id ||
          other.files[i].starred != files[i].starred ||
          other.files[i].shared != files[i].shared ||
          other.files[i].lastAccessedAt != files[i].lastAccessedAt) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    var h = files.length;
    for (final f in files) {
      h = Object.hash(h, f.id, f.lastAccessedAt, f.starred, f.shared);
    }
    return h;
  }
}
