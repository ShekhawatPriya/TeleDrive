import '../../models/drive_models.dart';

class FolderDeleteValidation {
  const FolderDeleteValidation({
    required this.canDelete,
    this.blockingFolderId,
    this.containsFiles = false,
    this.containsFolders = false,
  });

  final bool canDelete;
  final String? blockingFolderId;
  final bool containsFiles;
  final bool containsFolders;

  static const allowed = FolderDeleteValidation(canDelete: true);
}

class FolderDeleteGuard {
  const FolderDeleteGuard._();

  static FolderDeleteValidation validateFolder(
    DriveState state,
    DriveFolder folder,
  ) {
    final descendantIds = _descendantFolderIds(state, folder.id);
    final containsFolders = descendantIds.isNotEmpty;
    final containsFiles =
        folder.recursiveFileCount > 0 ||
        _hasActiveOptimisticFile(state, {folder.id, ...descendantIds});

    if (!containsFiles && !containsFolders) {
      return FolderDeleteValidation.allowed;
    }

    return FolderDeleteValidation(
      canDelete: false,
      blockingFolderId: folder.id,
      containsFiles: containsFiles,
      containsFolders: containsFolders,
    );
  }

  static FolderDeleteValidation validateFolders(
    DriveState state,
    Iterable<String> folderIds,
  ) {
    for (final id in folderIds) {
      final folder = _folderById(state, id);
      if (folder == null) continue;
      final validation = validateFolder(state, folder);
      if (!validation.canDelete) return validation;
    }
    return FolderDeleteValidation.allowed;
  }

  static DriveFolder? _folderById(DriveState state, String id) {
    for (final folder in state.folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  static Set<String> _descendantFolderIds(DriveState state, String folderId) {
    final found = <String>{};

    void visit(String id) {
      for (final child in state.folders.where((f) => f.parentId == id)) {
        if (found.add(child.id)) visit(child.id);
      }
    }

    visit(folderId);
    return found;
  }

  static bool _hasActiveOptimisticFile(
    DriveState state,
    Set<String> folderIds,
  ) {
    final checked = <String>{};
    for (final file in [...state.files, ...state.mediaFiles]) {
      if (!checked.add(file.id)) continue;
      if (!_isActiveOptimisticFile(file)) continue;
      if (file.parentId != null && folderIds.contains(file.parentId)) {
        return true;
      }
    }
    return false;
  }

  static bool _isActiveOptimisticFile(DriveFile file) {
    if (!file.isOptimistic) return false;
    return file.uploadStatus != 'failed' && file.uploadStatus != 'cancelled';
  }
}
