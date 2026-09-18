import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/download_cache.dart';
import '../../core/telegram/telegram_media_access_service.dart';
import '../../models/drive_models.dart';
import '../auth/auth_controller.dart';

final fileCopyShareServiceProvider = Provider<FileCopyShareService>((ref) {
  final auth = ref.watch(authControllerProvider.notifier);
  return FileCopyShareService(
    auth: auth,
    stage: (original, file, name, cancellation) {
      final user = auth.user!;
      return stageOriginalForSharing(
        original,
        file,
        name,
        cancellation,
        backend: AppConfig.storageNamespace,
        userId: user.userId,
        telegramId: user.telegramId,
      );
    },
    download: (file, cancellation, progress) async {
      // Private originals stay on the existing account-checked TDLib path.
      if (file.isClientManaged) {
        return ref
            .read(telegramMediaAccessServiceProvider)
            .downloadForPrivateView(
              file,
              cancelToken: cancellation,
              onProgress: progress,
            );
      }
      final user = auth.user;
      final url = file.downloadUrl;
      if (user == null || url == null) throw StateError('Original unavailable');
      final api = ref.read(apiClientProvider);
      final root = await getTemporaryDirectory();
      if (cancellation.isCancelled) throw cancellation.cancelError!;
      return DownloadCache(root).obtain(
        backend: AppConfig.storageNamespace,
        userId: user.userId,
        file: file,
        download: (path) async {
          await api.dio.download(
            url,
            path,
            cancelToken: cancellation,
            onReceiveProgress: progress,
          );
        },
      );
    },
  );
});

typedef OriginalCopyLoader =
    Future<File?> Function(DriveFile, CancelToken, ProgressCallback);

class CopyPreparationProgress {
  const CopyPreparationProgress({
    required this.name,
    required this.index,
    required this.count,
    this.preparingCopy = false,
    this.received = 0,
    this.total = 0,
  });
  final String name;
  final bool preparingCopy;
  final int index, count, received, total;
  double? get fraction =>
      !preparingCopy && total > 0 ? (received / total).clamp(0, 1) : null;
}

/// Serial preparation bounds memory/transfer pressure. Only complete originals
/// cross the native share boundary; cancellation/account changes discard results.
class FileCopyShareService {
  FileCopyShareService({
    required this.auth,
    required this.download,
    required this.stage,
  });
  final AuthController auth;
  final OriginalCopyLoader download;
  final OriginalCopyStager stage;
  Object get _identity => (
    auth.user?.userId,
    auth.user?.telegramId,
    auth.token,
    auth.switchingAccount,
  );

  Future<List<XFile>> prepare(
    List<DriveFile> files, {
    required CancelToken cancellation,
    required ValueChanged<CopyPreparationProgress> onProgress,
  }) async {
    if (auth.user == null || auth.switchingAccount)
      throw StateError('Account unavailable');
    final owner = _identity;
    void accountChanged() {
      if (_identity != owner && !cancellation.isCancelled)
        cancellation.cancel('Account changed');
    }

    void check() {
      accountChanged();
      if (cancellation.isCancelled) throw cancellation.cancelError!;
    }

    auth.addListener(accountChanged);
    final copies = <XFile>[];
    final usedNames = <String>{};
    try {
      for (var i = 0; i < files.length; i++) {
        check();
        final file = files[i];
        if (file.uploadStatus != null && file.uploadStatus != 'available') {
          throw StateError('Original is not ready');
        }
        void report(int received, int total) {
          if (!cancellation.isCancelled)
            onProgress(
              CopyPreparationProgress(
                name: file.name,
                index: i + 1,
                count: files.length,
                received: received,
                total: total,
              ),
            );
        }

        report(0, file.size);
        final original = await download(file, cancellation, report);
        check();
        if (original == null || !await original.exists())
          throw StateError('Original unavailable');
        final size = await original.length();
        check();
        if (size == 0 || (file.size > 0 && size != file.size))
          throw StateError('Original is incomplete');
        var name = file.name
            .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
            .trim();
        if (name.isEmpty || name == '.' || name == '..') name = 'file';
        final dot = name.lastIndexOf('.');
        final stem = dot > 0 ? name.substring(0, dot) : name;
        final extension = dot > 0 ? name.substring(dot) : '';
        var duplicate = 2;
        while (!usedNames.add(name.toLowerCase())) {
          name = '$stem (${duplicate++})$extension';
        }
        onProgress(
          CopyPreparationProgress(
            name: file.name,
            index: i + 1,
            count: files.length,
            preparingCopy: true,
          ),
        );
        final staged = await stage(original, file, name, cancellation);
        check();
        copies.add(XFile(staged.path, mimeType: file.mimeType));
        report(size, size);
      }
      check();
      return copies;
    } finally {
      auth.removeListener(accountChanged);
    }
  }
}

typedef OriginalCopyStager =
    Future<File> Function(
      File original,
      DriveFile file,
      String name,
      CancelToken cancellation,
    );

/// File-name overrides are ignored for existing paths by share_plus. Stage the
/// actual path with the original name, streaming to disk with bounded memory.
Future<File> stageOriginalForSharing(
  File original,
  DriveFile file,
  String name,
  CancelToken cancellation, {
  required String backend,
  required int userId,
  required int telegramId,
}) async {
  final root = await getTemporaryDirectory();
  if (cancellation.isCancelled) throw cancellation.cancelError!;
  return DownloadCache(root).obtain(
    backend: '$backend:share-copy:$telegramId',
    userId: userId,
    file: file.copyWith(name: name),
    download: (path) async {
      final sink = File(path).openWrite();
      try {
        await sink.addStream(
          original.openRead().map((chunk) {
            if (cancellation.isCancelled) throw cancellation.cancelError!;
            return chunk;
          }),
        );
        await sink.close();
      } catch (_) {
        // addStream may already close the file on failure. Preserve the
        // original cancellation/write error rather than replacing it.
        try {
          await sink.close();
        } catch (_) {}
        rethrow;
      }
    },
  );
}
