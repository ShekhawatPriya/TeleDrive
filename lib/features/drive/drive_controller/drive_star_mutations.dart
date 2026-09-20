part of '../drive_controller.dart';

extension _DriveStarMutations on DriveController {
  Future<void> _toggleStar(String id, {bool folder = false}) async {
    final key = '${folder ? 'folder' : 'file'}:$id';
    if (!_starMutations.add(key)) return;
    final generation = _accountGeneration;
    final currentFile = folder
        ? null
        : anyFile(id) ??
              state.starred.files.firstWhereOrNull((f) => f.id == id);
    final currentFolder = folder
        ? this.folder(id) ??
              state.starred.folders.firstWhereOrNull((f) => f.id == id)
        : null;
    final before = currentFolder?.starred ?? currentFile?.starred;
    if (before == null) {
      _starMutations.remove(key);
      return;
    }
    void apply(bool value) {
      _patchFlags(
        fileIds: folder ? {} : {id},
        folderIds: folder ? {id} : {},
        starred: value,
      );
      if (currentFile != null) {
        _patchStarredFile(
          (anyFile(id) ?? currentFile).copyWith(starred: value),
          starred: value,
        );
      }
      if (currentFolder != null) {
        _patchStarredFolder(
          (this.folder(id) ?? currentFolder).copyWith(starred: value),
          starred: value,
        );
      }
      _notifyListeners();
    }

    // Keep starred-only items addressable while an optimistic unstar removes
    // them from that collection, so concurrent metadata changes are retained.
    if (currentFile != null) _resolvedFiles.putIfAbsent(id, () => currentFile);
    if (currentFolder != null) _mergeFolderMetadata([currentFolder]);
    state = state.copyWith(clearError: true);
    apply(!before);
    try {
      final confirmed = folder
          ? (await _repo.setFolderStarred(id, !before)).starred
          : (await _repo.setFileStarred(id, !before)).starred;
      if (_isCurrentAccount(generation)) apply(confirmed);
    } catch (err) {
      if (_isCurrentAccount(generation)) {
        // Roll back only this flag, preserving concurrent shares/other items.
        apply(before);
        state = state.copyWith(
          error: _repo.api.errorMessage(err, 'Could not update star.'),
        );
        _notifyListeners();
      }
    } finally {
      if (_isCurrentAccount(generation)) _starMutations.remove(key);
    }
  }
}
