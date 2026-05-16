import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/storage/local_preferences.dart';
import '../../core/utils/file_type_detector.dart';
import '../../core/utils/iterable_ext.dart';
import '../../models/drive_models.dart';
import '../auth/auth_controller.dart';
import 'drive_repository.dart';

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
  );
});

class DriveController extends ChangeNotifier {
  DriveController(this._repo, this._prefs) {
    _loadRecent();
  }

  final DriveRepository _repo;
  final LocalPreferences _prefs;
  DriveState state = const DriveState();
  Map<String, String> _recent = {};

  List<DriveFile> get files => state.files
      .map((f) => f.copyWith(lastAccessedAt: _recent[f.id]))
      .toList();
  List<DriveFile> get mediaFiles => state.mediaFiles
      .map((f) => f.copyWith(lastAccessedAt: _recent[f.id]))
      .toList();
  List<DriveFolder> get folders => _withStats(state.folders, files);

  Future<void> _loadRecent() async {
    _recent = await _prefs.recentAccess();
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, clearError: true);
      notifyListeners();
    }
    try {
      final all = await _repo.listAllFiles();
      final media = await _repo.listFiles(type: 'media', limit: 60);
      final folders = await _repo.listFolders();
      state = state.copyWith(
        files: all.where((f) => f.uploadStatus == 'available').toList(),
        mediaFiles: media.files
            .where((f) => f.uploadStatus == 'available')
            .toList(),
        folders: folders,
        mediaCursor: media.nextCursor,
        loading: false,
        clearError: true,
      );
    } catch (err) {
      state = state.copyWith(
        loading: false,
        error: _repo.api.errorMessage(err, 'Failed to load drive.'),
      );
    }
    notifyListeners();
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
  DriveFolder? folder(String id) =>
      folders.where((f) => f.id == id).firstOrNull;

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

  Future<DriveFolder> createFolder(String name, String? parentId) async {
    final folder = await _repo.createFolder(name, parentId);
    state = state.copyWith(folders: [folder, ...state.folders]);
    notifyListeners();
    return folder;
  }

  Future<void> renameFolder(String id, String name) async {
    await _repo.renameFolder(id, name);
    state = state.copyWith(
      folders: state.folders
          .map((f) => f.id == id ? f.copyWith(name: name) : f)
          .toList(),
    );
    notifyListeners();
  }

  Future<void> deleteItems({
    List<String> fileIds = const [],
    List<String> folderIds = const [],
  }) async {
    final total = fileIds.length + folderIds.length;
    if (total == 0) return;
    var completed = 0;
    var failed = 0;
    final oldFiles = state.files;
    final oldMedia = state.mediaFiles;
    final oldFolders = state.folders;
    state = state.copyWith(
      files: state.files.where((f) => !fileIds.contains(f.id)).toList(),
      mediaFiles: state.mediaFiles
          .where((f) => !fileIds.contains(f.id))
          .toList(),
      folders: state.folders.where((f) => !folderIds.contains(f.id)).toList(),
      deleteProgress: (completed: 0, failed: 0, total: total),
    );
    notifyListeners();
    for (final id in fileIds) {
      try {
        await _repo.deleteFile(id);
      } catch (_) {
        failed++;
      } finally {
        completed++;
        state = state.copyWith(
          deleteProgress: (completed: completed, failed: failed, total: total),
        );
        notifyListeners();
      }
    }
    for (final id in folderIds) {
      try {
        await _repo.deleteFolder(id);
      } catch (_) {
        failed++;
      } finally {
        completed++;
        state = state.copyWith(
          deleteProgress: (completed: completed, failed: failed, total: total),
        );
        notifyListeners();
      }
    }
    if (failed > 0)
      state = state.copyWith(
        files: oldFiles,
        mediaFiles: oldMedia,
        folders: oldFolders,
      );
    Future<void>.delayed(Duration(milliseconds: failed > 0 ? 2200 : 900), () {
      state = state.copyWith(clearDeleteProgress: true);
      notifyListeners();
    });
  }

  void toggleStar(String id, {bool folder = false}) {
    if (folder) {
      state = state.copyWith(
        folders: state.folders
            .map((f) => f.id == id ? f.copyWith(starred: !f.starred) : f)
            .toList(),
      );
    } else {
      state = state.copyWith(
        files: state.files
            .map((f) => f.id == id ? f.copyWith(starred: !f.starred) : f)
            .toList(),
        mediaFiles: state.mediaFiles
            .map((f) => f.id == id ? f.copyWith(starred: !f.starred) : f)
            .toList(),
      );
    }
    notifyListeners();
  }

  Future<void> markAccessed(String id) async {
    _recent = {..._recent, id: DateTime.now().toIso8601String()};
    await _prefs.setRecentAccess(_recent);
    notifyListeners();
  }

  void syncOptimisticUploads(List<DriveFile> optimistic) {
    final serverIds = state.files.map((f) => f.id).toSet();
    final local = optimistic
        .where(
          (f) => !serverIds.contains(f.id) && f.uploadStatus != 'cancelled',
        )
        .toList();
    state = state.copyWith(
      files: [...local, ...state.files.where((f) => !f.isOptimistic)],
    );
    notifyListeners();
  }

  List<DriveFolder> _withStats(
    List<DriveFolder> rawFolders,
    List<DriveFile> rawFiles,
  ) {
    int countFiles(String folderId) {
      final direct = rawFiles.where((f) => f.parentId == folderId).length;
      final nested = rawFolders
          .where((f) => f.parentId == folderId)
          .fold(0, (sum, f) => sum + countFiles(f.id));
      return direct + nested;
    }

    int sizeFiles(String folderId) {
      final direct = rawFiles
          .where((f) => f.parentId == folderId)
          .fold(0, (sum, f) => sum + f.size);
      final nested = rawFolders
          .where((f) => f.parentId == folderId)
          .fold(0, (sum, f) => sum + sizeFiles(f.id));
      return direct + nested;
    }

    return rawFolders
        .map(
          (f) => f.copyWith(
            recursiveFileCount: countFiles(f.id),
            recursiveSize: sizeFiles(f.id),
          ),
        )
        .toList();
  }
}
