import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/media/gallery_media_scanner.dart';
import '../../auth/auth_controller.dart';
import '../../drive/drive_controller.dart';
import '../../drive/drive_repository.dart';
import '../../upload/upload_controller.dart';
import '../gallery_backup_asset_store.dart';
import 'free_up_space_models.dart';

export 'free_up_space_models.dart';

part 'free_up_space_scan.dart';

final freeUpSpaceControllerProvider =
    ChangeNotifierProvider<FreeUpSpaceController>((ref) {
      final controller = FreeUpSpaceController(
        auth: ref.read(authControllerProvider),
        uploads: ref.read(uploadControllerProvider),
        drive: ref.read(driveRepositoryProvider),
      );
      Future.microtask(controller.scan);
      return controller;
    });

class FreeUpSpaceController extends ChangeNotifier {
  FreeUpSpaceController({
    required AuthController auth,
    required UploadController uploads,
    required DriveRepository drive,
    GalleryMediaScanner scanner = const GalleryMediaScanner(),
    GalleryBackupAssetStore assetStore = const GalleryBackupAssetStore(),
    bool Function() isAndroid = _defaultIsAndroid,
  }) : _auth = auth,
       _uploads = uploads,
       _drive = drive,
       _scanner = scanner,
       _assetStore = assetStore,
       _isAndroid = isAndroid;

  final AuthController _auth;
  final UploadController _uploads;
  final DriveRepository _drive;
  final GalleryMediaScanner _scanner;
  final GalleryBackupAssetStore _assetStore;
  final bool Function() _isAndroid;

  FreeUpSpaceState state = const FreeUpSpaceState();

  Future<void> scan() async {
    if (state.scanning || state.deleting) return;
    state = state.copyWith(
      scanning: true,
      userCancelledLastDelete: false,
      clearError: true,
      clearLastSuccessMessage: true,
    );
    notifyListeners();
    try {
      final next = await _buildScanState();
      state = next.copyWith(scanning: false);
    } catch (err) {
      state = FreeUpSpaceState(
        lastScanAt: DateTime.now(),
        error:
            'TeleDrive could not confirm which Auto Backup items are safely stored in the cloud. Nothing was deleted.',
      );
    }
    notifyListeners();
  }

  Future<FreeUpSpaceDeleteSummary> freeUpSpace() async {
    if (state.deleting || state.candidates.isEmpty) {
      return const FreeUpSpaceDeleteSummary(
        requested: 0,
        deleted: 0,
        failed: 0,
        deletedBytes: 0,
        userCancelled: false,
      );
    }
    state = state.copyWith(
      deleting: true,
      userCancelledLastDelete: false,
      clearError: true,
      clearLastSuccessMessage: true,
    );
    notifyListeners();

    var requested = 0;
    var deleted = 0;
    var failed = 0;
    var deletedBytes = 0;
    final scope = _assetScope();
    try {
      if (scope == null) {
        throw Exception('Sign in before freeing space.');
      }
      final verified = await _buildScanState();
      final candidates = verified.candidates;
      if (candidates.isEmpty) {
        state = verified.copyWith(deleting: false);
        notifyListeners();
        return const FreeUpSpaceDeleteSummary(
          requested: 0,
          deleted: 0,
          failed: 0,
          deletedBytes: 0,
          userCancelled: false,
        );
      }

      const chunkSize = 200;
      final byUri = {
        for (final candidate in candidates) candidate.contentUri: candidate,
      };
      for (var start = 0; start < candidates.length; start += chunkSize) {
        final chunk = candidates.skip(start).take(chunkSize).toList();
        final result = await _scanner.deleteMediaUris(
          chunk.map((candidate) => candidate.contentUri).toList(),
        );
        requested += result.requested;
        if (result.userCancelled) {
          state = verified.copyWith(
            deleting: false,
            userCancelledLastDelete: true,
            lastSuccessMessage: 'Nothing was deleted.',
          );
          notifyListeners();
          return FreeUpSpaceDeleteSummary(
            requested: requested,
            deleted: deleted,
            failed: failed + result.failed,
            deletedBytes: deletedBytes,
            userCancelled: true,
          );
        }

        final deletedFingerprints = <String>[];
        for (final uri in result.deletedUris) {
          final candidate = byUri[uri];
          if (candidate == null) continue;
          deleted++;
          deletedBytes += candidate.sizeBytes;
          deletedFingerprints.add(candidate.fingerprint);
        }
        if (deletedFingerprints.isNotEmpty) {
          await _assetStore.markCleaned(scope, deletedFingerprints);
        }

        for (final uri in result.failedUris) {
          final candidate = byUri[uri];
          if (candidate == null) continue;
          failed++;
          await _assetStore.markCleanupFailed(
            scope,
            candidate.fingerprint,
            failureCode: 'android_delete_failed',
            failureMessage: 'Android could not remove this local media item.',
          );
        }
      }

      final refreshed = await _buildScanState();
      final message = failed > 0
          ? 'Freed $deleted items. $failed could not be removed.'
          : deletedBytes > 0
          ? 'Freed up ${_formatBytes(deletedBytes)} from this device.'
          : null;
      state = refreshed.copyWith(
        deleting: false,
        lastSuccessMessage: message,
        userCancelledLastDelete: false,
      );
      notifyListeners();
      return FreeUpSpaceDeleteSummary(
        requested: requested,
        deleted: deleted,
        failed: failed,
        deletedBytes: deletedBytes,
        userCancelled: false,
      );
    } catch (err) {
      state = FreeUpSpaceState(
        lastScanAt: DateTime.now(),
        error:
            'TeleDrive could not confirm which Auto Backup items are safely stored in the cloud. Nothing was deleted.',
      );
      notifyListeners();
      return FreeUpSpaceDeleteSummary(
        requested: requested,
        deleted: deleted,
        failed: failed,
        deletedBytes: deletedBytes,
        userCancelled: false,
      );
    }
  }

  void clearTransientMessages() {
    state = state.copyWith(clearError: true, clearLastSuccessMessage: true);
    notifyListeners();
  }
}
