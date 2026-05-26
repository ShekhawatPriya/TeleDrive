part of '../drive_controller.dart';

extension _DriveFileFetch on DriveController {
  Future<DriveFile?> _fetchFile(String id) async {
    try {
      final fetched = await _repo.getFile(id);
      _resolvedFiles[id] = fetched;
      // If the file's parent folder is already loaded, splice it into that
      // page so other consumers (folder view, etc.) see it.
      final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
      final parentId = fetched.parentId;
      final page = pages[parentId];
      if (page != null && page.loaded && !page.files.any((f) => f.id == id)) {
        pages[parentId] = page.copyWith(files: [...page.files, fetched]);
        state = state.copyWith(folderPages: pages);
        _refreshFlatAggregates();
      }
      _notifyListeners();
      return fetched;
    } catch (_) {
      return null;
    }
  }
}
