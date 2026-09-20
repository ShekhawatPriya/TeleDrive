part of '../drive_controller.dart';

extension _DriveShareUpdates on DriveController {
  void _markShared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) => _patchFlags(fileIds: fileIds, folderIds: folderIds, shared: true);

  void _markUnshared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) => _patchFlags(fileIds: fileIds, folderIds: folderIds, shared: false);

  // Patch each representation. Metadata responses must not replace media dates,
  // local paths, revisions or a concurrent change to a different flag.
  void _patchFlags({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
    bool? starred,
    bool? shared,
  }) {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    if (shared != null) {
      for (final key in [
        for (final id in fileIds) 'file:$id',
        for (final id in folderIds) 'folder:$id',
      ]) {
        _sharedVersions[key] = (_sharedVersions[key] ?? 0) + 1;
      }
    }
    DriveFile file(DriveFile value) => fileIds.contains(value.id)
        ? value.copyWith(starred: starred, shared: shared)
        : value;
    DriveFolder folder(DriveFolder value) => folderIds.contains(value.id)
        ? value.copyWith(starred: starred, shared: shared)
        : value;
    final pages = {
      for (final entry in state.folderPages.entries)
        entry.key: entry.value.copyWith(
          files: entry.value.files.map(file).toList(),
          subfolders: entry.value.subfolders.map(folder).toList(),
        ),
    };
    _resolvedFiles.updateAll((_, value) => file(value));
    state = state.copyWith(
      folderPages: pages,
      files: state.files.map(file).toList(),
      mediaFiles: state.mediaFiles.map(file).toList(),
      folders: state.folders.map(folder).toList(),
      starred: state.starred.copyWith(
        files: state.starred.files.map(file).toList(),
        folders: state.starred.folders.map(folder).toList(),
      ),
    );
    _notifyListeners();
  }
}
