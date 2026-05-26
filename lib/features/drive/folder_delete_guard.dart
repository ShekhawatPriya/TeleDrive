import '../../models/drive_models.dart';

/// Folder delete pre-check.
///
/// After the on-demand Drive refactor, `state.folders` is intentionally
/// incomplete (only folders the user has visited or that came in the root
/// bootstrap). A client-side recursive descendant walk would silently miss
/// subfolders that haven't been loaded.
///
/// The server is the source of truth for "is this folder empty?" — it
/// enforces this in `FolderService._assert_folder_empty` and surfaces a
/// `folder_not_empty` error on `trash_folder`. The pre-check here is a fast
/// UX path: when the directly-known counts already say the folder isn't
/// empty, block immediately so the user gets a clear message without a round
/// trip. When the local view says it might be empty, we let the server
/// confirm — the delete call will throw `folder_not_empty` and the existing
/// error dialog surfaces.
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
    final loadedChildFolders = state.folderPages[folder.id]?.subfolders ?? const [];
    final containsFolders = loadedChildFolders.isNotEmpty;
    // recursiveFileCount is currently populated from `direct_file_count` on
    // the backend (see folder_response_direct). It accurately reflects direct
    // children at the moment of the last folder fetch, which is good enough
    // for the fast-path check; deeper non-emptiness is caught by the server.
    final containsFiles =
        folder.recursiveFileCount > 0 ||
        _hasActiveOptimisticFile(state, folder.id);

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

  static bool _hasActiveOptimisticFile(DriveState state, String folderId) {
    final page = state.folderPages[folderId];
    if (page == null) return false;
    for (final file in page.files) {
      if (_isActiveOptimisticFile(file)) return true;
    }
    return false;
  }

  static bool _isActiveOptimisticFile(DriveFile file) {
    if (!file.isOptimistic) return false;
    return file.uploadStatus != 'failed' && file.uploadStatus != 'cancelled';
  }
}
