import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/storage/local_preferences.dart';
import '../../core/utils/file_type_detector.dart';
import '../../core/utils/iterable_ext.dart';
import '../../models/drive_models.dart';
import '../auth/auth_controller.dart';
import '../profile/app_settings_controller.dart';
import 'drive_repository.dart';

part 'drive_controller/drive_mutations.dart';
part 'drive_controller/drive_refresh.dart';

final localPreferencesProvider = Provider<LocalPreferences>(
  (ref) => LocalPreferences(),
);
final driveRepositoryProvider = Provider<DriveRepository>(
  (ref) => DriveRepository(ref.watch(apiClientProvider)),
);
final driveControllerProvider = ChangeNotifierProvider<DriveController>((ref) {
  return DriveController(
    ref.watch(driveRepositoryProvider),
    ref.watch(localPreferencesProvider),
    ref.read(appSettingsControllerProvider),
    ref.read(authControllerProvider),
  );
});

class DriveController extends ChangeNotifier {
  DriveController(this._repo, this._prefs, this._settings, this._auth) {
    _loadRecent();
  }

  final DriveRepository _repo;
  final LocalPreferences _prefs;
  final AppSettingsController _settings;
  final AuthController _auth;
  DriveState state = const DriveState();
  Map<String, String> _recent = {};
  Future<void>? _refreshing;
  DateTime? _lastRefreshCompletedAt;
  final Set<String?> _staleFolderIds = {};

  void setActiveFolderId(String? folderId) {
    if (state.activeFolderId == folderId) return;
    state = state.copyWith(activeFolderId: folderId);
    notifyListeners();

    if (_staleFolderIds.contains(folderId)) {
      refresh(silent: true, force: true);
    }
  }

  Future<void> resetForAccountSwitch() async {
    state = const DriveState(loading: true);
    _recent = {};
    _refreshing = null;
    _lastRefreshCompletedAt = null;
    _staleFolderIds.clear();
    notifyListeners();
    await _loadRecent();
  }

  List<DriveFile> get files => state.files
      .map((f) => f.copyWith(lastAccessedAt: _recent[f.id]))
      .toList();
  List<DriveFile> get mediaFiles => state.mediaFiles
      .map((f) => f.copyWith(lastAccessedAt: _recent[f.id]))
      .toList();
  List<DriveFolder> get folders => state.folders;

  Future<void> refresh({bool silent = false, bool force = false}) async {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    if (!force && silent && _lastRefreshCompletedAt != null) {
      final elapsed = DateTime.now().difference(_lastRefreshCompletedAt!);
      if (elapsed < const Duration(seconds: 1)) return;
    }
    final refresh = _refresh(silent: silent);
    _refreshing = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshing, refresh)) {
        _refreshing = null;
      }
    }
  }

  void applyDriveState(DriveSnapshot snapshot, {bool notify = true}) {
    final incomingFiles = snapshot.files
        .where((f) => f.uploadStatus == 'available')
        .toList();
    final incomingMedia = snapshot.mediaFiles
        .where((f) => f.uploadStatus == 'available')
        .toList();

    final updatedFiles = _reconcileFiles(
      existing: state.files,
      incoming: incomingFiles,
      authoritative: true,
    );
    final updatedMedia = _reconcileFiles(
      existing: state.mediaFiles,
      incoming: incomingMedia,
      authoritative: true,
    );

    final keptOptimisticFolders = state.folders
        .where((f) => f.isOptimistic)
        .toList();
    final folderIds = <String>{};
    final reconciledFolders = <DriveFolder>[];
    for (final f in [...keptOptimisticFolders, ...snapshot.folders]) {
      if (folderIds.add(f.id)) {
        reconciledFolders.add(f);
      }
    }

    state = state.copyWith(
      files: updatedFiles,
      mediaFiles: updatedMedia,
      folders: reconciledFolders,
      mediaCursor: snapshot.mediaCursor,
      loading: false,
      clearError: true,
    );
    _lastRefreshCompletedAt = DateTime.now();
    if (notify) notifyListeners();
  }

  Future<void> loadMoreMedia() async {
    if (state.mediaCursor == null || state.loadingMoreMedia) return;
    state = state.copyWith(loadingMoreMedia: true);
    notifyListeners();
    try {
      final page = await _repo.listFiles(
        type: 'media',
        cursor: state.mediaCursor,
        limit: 60,
        allFolders: true,
      );
      final ids = state.mediaFiles.map((f) => f.id).toSet();
      state = state.copyWith(
        mediaFiles: [
          ...state.mediaFiles,
          ...page.files.where((f) => !ids.contains(f.id)),
        ],
        mediaCursor: page.nextCursor,
        loadingMoreMedia: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMoreMedia: false);
    }
    notifyListeners();
  }

  List<DriveFile> filesInFolder(String? folderId) =>
      files.where((f) => f.parentId == folderId).toList();
  List<DriveFolder> foldersInFolder(String? folderId) =>
      folders.where((f) => f.parentId == folderId).toList();
  DriveFile? file(String id) => files.where((f) => f.id == id).firstOrNull;
  DriveFile? anyFile(String id) =>
      file(id) ?? mediaFiles.where((f) => f.id == id).firstOrNull;
  DriveFolder? folder(String id) =>
      folders.where((f) => f.id == id).firstOrNull;

  void markShared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    state = state.copyWith(
      files: state.files
          .map((f) => fileIds.contains(f.id) ? f.copyWith(shared: true) : f)
          .toList(),
      mediaFiles: state.mediaFiles
          .map((f) => fileIds.contains(f.id) ? f.copyWith(shared: true) : f)
          .toList(),
      folders: state.folders
          .map((f) => folderIds.contains(f.id) ? f.copyWith(shared: true) : f)
          .toList(),
    );
    notifyListeners();
  }

  void markUnshared({
    Set<String> fileIds = const {},
    Set<String> folderIds = const {},
  }) {
    if (fileIds.isEmpty && folderIds.isEmpty) return;
    state = state.copyWith(
      files: state.files
          .map((f) => fileIds.contains(f.id) ? f.copyWith(shared: false) : f)
          .toList(),
      mediaFiles: state.mediaFiles
          .map((f) => fileIds.contains(f.id) ? f.copyWith(shared: false) : f)
          .toList(),
      folders: state.folders
          .map((f) => folderIds.contains(f.id) ? f.copyWith(shared: false) : f)
          .toList(),
    );
    notifyListeners();
  }

  List<DriveFolder> folderPath(String id) {
    final path = <DriveFolder>[];
    DriveFolder? current = folder(id);
    while (current != null) {
      path.insert(0, current);
      current = current.parentId == null ? null : folder(current.parentId!);
    }
    return path;
  }

  List<DriveFile> recentFiles() {
    final result = files.where((f) => f.lastAccessedAt != null).toList()
      ..sort((a, b) => b.lastAccessedAt!.compareTo(a.lastAccessedAt!));
    return result.take(5).toList();
  }

  List<DriveFile> photoFiles(String filter) {
    final list = [...mediaFiles.where(isMediaFile)]
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return switch (filter) {
      'images' => list.where(isImageFile).toList(),
      'videos' => list.where(isVideoFile).toList(),
      'starred' => list.where((f) => f.starred).toList(),
      _ => list,
    };
  }

  ({List<DriveFile> files, List<DriveFolder> folders}) starred() {
    return (
      files: files.where((f) => f.starred).toList(),
      folders: folders.where((f) => f.starred).toList(),
    );
  }

  Future<DriveFolder> createFolder(String name, String? parentId) =>
      _createFolder(name, parentId);

  Future<void> renameFolder(String id, String name) => _renameFolder(id, name);

  Future<void> moveFile(String fileId, String? targetFolderId) =>
      _moveFile(fileId, targetFolderId);

  Future<void> moveFolder(String folderId, String? targetParentId) =>
      _moveFolder(folderId, targetParentId);

  Future<void> deleteItems({
    List<String> fileIds = const [],
    List<String> folderIds = const [],
  }) => _deleteItems(fileIds: fileIds, folderIds: folderIds);

  Future<void> restoreFile(String id) async {
    await _repo.restoreFile(id);
    await refresh(silent: true, force: true);
  }

  Future<void> restoreFolder(String id) async {
    await _repo.restoreFolder(id);
    await refresh(silent: true, force: true);
  }

  Future<void> purgeFile(String id) async {
    await _repo.purgeFile(id);
    await refresh(silent: true, force: true);
  }

  Future<void> purgeFolder(String id) async {
    await _repo.purgeFolder(id);
    await refresh(silent: true, force: true);
  }

  Future<void> purgeAllTrash() async {
    await _repo.purgeAllTrash();
    await refresh(silent: true, force: true);
  }

  Future<void> toggleStar(String id, {bool folder = false}) =>
      _toggleStar(id, folder: folder);

  Future<void> markAccessed(String id) async {
    _recent = {..._recent, id: DateTime.now().toIso8601String()};
    await _prefs.setRecentAccess(_recent, userId: _auth.activeAccount?.userId);
    notifyListeners();
  }

  void _notifyListeners() {
    notifyListeners();
  }

  void syncOptimisticUploads(List<DriveFile> optimistic) {
    final keep = optimistic
        .where((f) => f.uploadStatus != 'cancelled')
        .toList();
    final updatedFiles = _reconcileFiles(
      existing: state.files,
      incoming: keep,
      removeOrphanedOptimistic: true,
    );

    final keepMedia = keep.where(isMediaFile).toList();
    final updatedMedia = _reconcileFiles(
      existing: state.mediaFiles,
      incoming: keepMedia,
      removeOrphanedOptimistic: true,
    );

    state = state.copyWith(files: updatedFiles, mediaFiles: updatedMedia);
    notifyListeners();
  }

  Set<String> _descendantFolderIds(String folderId) {
    final found = <String>{};
    void visit(String id) {
      for (final child in state.folders.where((f) => f.parentId == id)) {
        if (found.add(child.id)) visit(child.id);
      }
    }

    visit(folderId);
    return found;
  }
}
