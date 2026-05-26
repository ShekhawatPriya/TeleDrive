part of '../drive_controller.dart';

extension _DriveFolderHelpers on DriveController {
  void _patchStarredFile(DriveFile file, {required bool starred}) {
    final cache = state.starred;
    if (!cache.loaded) return;
    if (starred) {
      if (cache.files.any((f) => f.id == file.id)) return;
      state = state.copyWith(
        starred: cache.copyWith(files: [file, ...cache.files]),
      );
    } else {
      final next = cache.files.where((f) => f.id != file.id).toList();
      if (next.length == cache.files.length) return;
      state = state.copyWith(starred: cache.copyWith(files: next));
    }
  }

  void _patchStarredFolder(DriveFolder folder, {required bool starred}) {
    final cache = state.starred;
    if (!cache.loaded) return;
    if (starred) {
      if (cache.folders.any((f) => f.id == folder.id)) return;
      state = state.copyWith(
        starred: cache.copyWith(folders: [folder, ...cache.folders]),
      );
    } else {
      final next = cache.folders.where((f) => f.id != folder.id).toList();
      if (next.length == cache.folders.length) return;
      state = state.copyWith(starred: cache.copyWith(folders: next));
    }
  }

  // Folder page helpers -----------------------------------------------------

  void _insertOptimisticFolder(String? parentId, DriveFolder folder) {
    final page = state.folderPages[parentId] ?? const DriveFolderPage();
    final next = [folder, ...page.subfolders];
    _applyFolderPage(parentId, page.copyWith(subfolders: next));
    _mergeFolderMetadata([folder]);
  }

  void _replaceFolderEverywhere(String oldId, DriveFolder replacement) {
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.subfolders.any((f) => f.id == oldId)) {
        final next = page.subfolders
            .map((f) => f.id == oldId ? replacement : f)
            .toList();
        pages[parent] = page.copyWith(subfolders: next);
      }
    });
    state = state.copyWith(folderPages: pages);
    _mergeFolderMetadata([replacement]);
  }

  void _removeFolderEverywhere(String folderId) {
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    pages.forEach((parent, page) {
      if (page.subfolders.any((f) => f.id == folderId)) {
        pages[parent] = page.copyWith(
          subfolders: page.subfolders.where((f) => f.id != folderId).toList(),
        );
      }
    });
    state = state.copyWith(folderPages: pages);
    final byId = {for (final f in state.folders) f.id: f};
    if (byId.remove(folderId) != null) {
      state = state.copyWith(folders: byId.values.toList());
    }
  }

  void _removeFileFromAllPages(String fileId) {
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    var changed = false;
    pages.forEach((parent, page) {
      if (page.files.any((f) => f.id == fileId)) {
        pages[parent] = page.copyWith(
          files: page.files.where((f) => f.id != fileId).toList(),
        );
        changed = true;
      }
    });
    if (changed) {
      state = state.copyWith(folderPages: pages);
      _refreshFlatAggregates();
    }
  }

  // Snapshots & lookups -----------------------------------------------------
}
