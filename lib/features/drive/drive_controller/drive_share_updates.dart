part of '../drive_controller.dart';

extension _DriveShareUpdates on DriveController {
  void _markShared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    if (fileIds.isNotEmpty) {
      final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
      pages.forEach((parent, page) {
        if (page.files.any((file) => fileIds.contains(file.id))) {
          pages[parent] = page.copyWith(
            files: page.files
                .map(
                  (file) => fileIds.contains(file.id)
                      ? file.copyWith(shared: true)
                      : file,
                )
                .toList(),
          );
        }
      });
      state = state.copyWith(folderPages: pages);
      _refreshFlatAggregates();
    }
    if (folderIds.isNotEmpty) {
      final byId = {for (final folder in state.folders) folder.id: folder};
      for (final id in folderIds) {
        final folder = byId[id];
        if (folder != null) byId[id] = folder.copyWith(shared: true);
      }
      state = state.copyWith(folders: byId.values.toList());
    }
    _notifyListeners();
  }

  void _markUnshared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    if (fileIds.isNotEmpty) {
      final pages = Map<String?, DriveFolderPage>.of(state.folderPages);
      pages.forEach((parent, page) {
        if (page.files.any((file) => fileIds.contains(file.id))) {
          pages[parent] = page.copyWith(
            files: page.files
                .map(
                  (file) => fileIds.contains(file.id)
                      ? file.copyWith(shared: false)
                      : file,
                )
                .toList(),
          );
        }
      });
      state = state.copyWith(folderPages: pages);
      _refreshFlatAggregates();
    }
    if (folderIds.isNotEmpty) {
      final byId = {for (final folder in state.folders) folder.id: folder};
      for (final id in folderIds) {
        final folder = byId[id];
        if (folder != null) byId[id] = folder.copyWith(shared: false);
      }
      state = state.copyWith(folders: byId.values.toList());
    }
    _notifyListeners();
  }
}
