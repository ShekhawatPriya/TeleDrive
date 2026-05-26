import 'package:flutter_m_fsdk/features/drive/folder_delete_guard.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FolderDeleteGuard', () {
    test('allows an empty folder', () {
      final folder = _folder('1');
      final state = DriveState(folders: [folder]);

      final result = FolderDeleteGuard.validateFolder(state, folder);

      expect(result.canDelete, isTrue);
      expect(result.blockingFolderId, isNull);
      expect(result.containsFiles, isFalse);
      expect(result.containsFolders, isFalse);
    });

    test('blocks when recursiveFileCount is greater than zero', () {
      final folder = _folder('1', recursiveFileCount: 2);
      final state = DriveState(folders: [folder]);

      final result = FolderDeleteGuard.validateFolder(state, folder);

      expect(result.canDelete, isFalse);
      expect(result.blockingFolderId, '1');
      expect(result.containsFiles, isTrue);
      expect(result.containsFolders, isFalse);
    });

    test('blocks active optimistic upload placeholders in the folder page', () {
      final folder = _folder('1');
      final optimistic = _file(
        'file-1',
        parentId: '1',
        uploadStatus: 'uploading',
      );
      final state = DriveState(
        folders: [folder],
        folderPages: {
          '1': DriveFolderPage(files: [optimistic], loaded: true),
        },
      );

      final result = FolderDeleteGuard.validateFolder(state, folder);

      expect(result.canDelete, isFalse);
      expect(result.containsFiles, isTrue);
      expect(result.containsFolders, isFalse);
    });

    test('blocks when the folder page has loaded subfolders', () {
      final folder = _folder('1');
      final child = _folder('2', parentId: '1');
      final state = DriveState(
        folders: [folder, child],
        folderPages: {
          '1': DriveFolderPage(subfolders: [child], loaded: true),
        },
      );

      final result = FolderDeleteGuard.validateFolder(state, folder);

      expect(result.canDelete, isFalse);
      expect(result.containsFolders, isTrue);
    });

    test('ignores failed and cancelled optimistic files', () {
      final folder = _folder('1');
      final state = DriveState(
        folders: [folder],
        folderPages: {
          '1': DriveFolderPage(
            files: [
              _file('file-1', parentId: '1', uploadStatus: 'failed'),
              _file('file-2', parentId: '1', uploadStatus: 'cancelled'),
            ],
            loaded: true,
          ),
        },
      );

      final result = FolderDeleteGuard.validateFolder(state, folder);

      expect(result.canDelete, isTrue);
      expect(result.containsFiles, isFalse);
    });

    test('allows folder when only deep descendants might be non-empty — server '
        'enforces folder_not_empty', () {
      // After the on-demand refactor, the guard does not walk descendants
      // client-side because state.folders is intentionally incomplete. The
      // server-side _assert_folder_empty is the source of truth and surfaces
      // a folder_not_empty error if the delete is actually unsafe.
      final folder = _folder('1');
      final child = _folder('2', parentId: '1');
      final grandchild = _folder('3', parentId: '2');
      // Note: no folderPages entry for '1', so the guard sees nothing.
      final state = DriveState(folders: [folder, child, grandchild]);

      final result = FolderDeleteGuard.validateFolder(state, folder);

      expect(result.canDelete, isTrue);
    });

    test('validateFolders returns the first blocked selected folder', () {
      final first = _folder('1');
      final second = _folder('2', recursiveFileCount: 1);
      final state = DriveState(folders: [first, second]);

      final result = FolderDeleteGuard.validateFolders(state, ['1', '2']);

      expect(result.canDelete, isFalse);
      expect(result.blockingFolderId, '2');
      expect(result.containsFiles, isTrue);
    });
  });
}

DriveFolder _folder(String id, {String? parentId, int recursiveFileCount = 0}) {
  return DriveFolder(
    id: id,
    name: 'Folder $id',
    parentId: parentId,
    modifiedAt: '2026-05-20T00:00:00.000Z',
    createdAt: '2026-05-20T00:00:00.000Z',
    recursiveFileCount: recursiveFileCount,
  );
}

DriveFile _file(String id, {required String parentId, String? uploadStatus}) {
  return DriveFile(
    id: id,
    name: 'File $id.txt',
    kind: FileKind.text,
    size: 1,
    modifiedAt: '2026-05-20T00:00:00.000Z',
    createdAt: '2026-05-20T00:00:00.000Z',
    parentId: parentId,
    starred: false,
    uploadStatus: uploadStatus,
    isOptimistic: true,
  );
}
