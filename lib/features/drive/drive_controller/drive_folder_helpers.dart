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

  /// Locally adjusts the displayed recursive file count / size of [folderId]
  /// and every ancestor after a mutation this client performed (upload
  /// commit, delete, move). These are instant estimates: server fetches
  /// overwrite them with authoritative values, and [markStale] guarantees
  /// such a fetch happens on the next visit to any affected folder.
  void _bumpFolderAggregates(
    String? folderId, {
    required int fileCountDelta,
    required int sizeDelta,
    bool markStale = true,
  }) {
    if (markStale) _markFolderAndAncestorsStale(folderId);
    if (folderId == null) return;
    final chain = folderPath(folderId);
    // Unknown metadata (e.g. destination never visited): stale marking above
    // is all we can do — the next fetch reconciles.
    if (chain.isEmpty) return;
    if (fileCountDelta == 0 && sizeDelta == 0) return;

    int clamped(int value) => value < 0 ? 0 : value;
    final updatedById = <String, DriveFolder>{
      for (final f in chain)
        f.id: f.copyWith(
          recursiveFileCount: clamped(f.recursiveFileCount + fileCountDelta),
          recursiveSize: clamped(f.recursiveSize + sizeDelta),
        ),
    };

    // Breadcrumbs / folder title read the global metadata cache.
    _mergeFolderMetadata(updatedById.values);

    // Folder tiles render from each page's `subfolders` list.
    final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
    var pagesChanged = false;
    pages.forEach((parent, page) {
      if (!page.subfolders.any((f) => updatedById.containsKey(f.id))) return;
      pages[parent] = page.copyWith(
        subfolders: page.subfolders.map((f) => updatedById[f.id] ?? f).toList(),
      );
      pagesChanged = true;
    });
    if (pagesChanged) {
      state = state.copyWith(folderPages: pages);
    }

    final starred = state.starred;
    if (starred.loaded &&
        starred.folders.any((f) => updatedById.containsKey(f.id))) {
      state = state.copyWith(
        starred: starred.copyWith(
          folders: starred.folders.map((f) => updatedById[f.id] ?? f).toList(),
        ),
      );
    }
    _notifyListeners();
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
