import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/storage/local_preferences.dart';
import 'package:flutter_m_fsdk/features/auth/auth_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_controller.dart';
import 'package:flutter_m_fsdk/features/drive/drive_repository.dart';
import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_m_fsdk/models/account_vault.dart';
import 'package:flutter_m_fsdk/models/drive_models.dart';

class _Repo implements DriveRepository {
  final bootstrap = Completer<DriveSnapshot>();
  final deletion = Completer<void>();
  final deleted = <String>[];
  @override
  Future<DriveSnapshot> getDriveState() => bootstrap.future;
  @override
  Future<void> deleteFile(String id) {
    deleted.add(id);
    return deletion.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Preferences implements LocalPreferences {
  @override
  Future<Map<String, String>> recentAccess({int? userId}) async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Settings implements AppSettingsController {
  @override
  AppSettingsState get state => const AppSettingsState();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Auth implements AuthController {
  @override
  SavedAccount? get activeAccount => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('late bootstrap cannot restore the previous account files', () async {
    final repo = _Repo();
    final drive = DriveController(repo, _Preferences(), _Settings(), _Auth());
    addTearDown(drive.dispose);
    final pending = drive.refresh();
    await drive.resetForAccountSwitch();
    repo.bootstrap.complete(
      DriveSnapshot(
        files: [
          DriveFile(
            id: 'old',
            name: 'Private',
            kind: FileKind.text,
            size: 1,
            modifiedAt: '',
            createdAt: '',
            parentId: null,
            starred: false,
            uploadStatus: 'available',
          ),
        ],
        mediaFiles: const [],
        folders: const [],
      ),
    );
    await pending;
    expect(drive.files, isEmpty);
  });
  test(
    'bulk delete stops before sending another account a remaining request',
    () async {
      final repo = _Repo();
      final drive = DriveController(repo, _Preferences(), _Settings(), _Auth());
      addTearDown(drive.dispose);
      final pending = drive.deleteItems(fileIds: ['1', '2']);
      expect(repo.deleted, ['1']);
      await drive.resetForAccountSwitch();
      repo.deletion.complete();
      await pending;
      expect(repo.deleted, ['1']);
      expect(drive.state.deleteProgress, isNull);
    },
  );
}
