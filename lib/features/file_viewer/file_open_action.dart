import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/download_cache.dart';
import '../../core/telegram/telegram_transfer_service.dart';
import '../../models/drive_models.dart';
import '../auth/auth_controller.dart';
import '../auth/tdlib_session_controller.dart';
import '../drive/drive_controller.dart';

/// Shared opening path for Drive and Photos, with an account boundary at every
/// asynchronous handoff and complete-file promotion for HTTP downloads.
Future<void> openDriveFileExternally(
  BuildContext context,
  WidgetRef ref,
  DriveFile file, {
  required String returnTo,
}) async {
  final api = ref.read(apiClientProvider);
  final user = ref.read(authControllerProvider).user;
  if (user == null) return;
  bool active() =>
      context.mounted &&
      ref.read(authControllerProvider).user?.userId == user.userId;
  final messenger = ScaffoldMessenger.of(context);
  void reconnect() {
    if (active())
      context.go(
        Uri(
          path: '/tdlib-session',
          queryParameters: {'returnTo': returnTo},
        ).toString(),
      );
  }

  try {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Preparing file…'),
        duration: Duration(seconds: 1),
      ),
    );
    String path;
    if (file.isClientManaged) {
      if (!ref.read(tdlibSessionControllerProvider).isReadyForActiveUser) {
        reconnect();
        return;
      }
      final media = await ref
          .read(driveRepositoryProvider)
          .mediaRef(file.id, variant: 'original');
      if (!active()) return;
      final telegramRef = media.ref;
      if (telegramRef == null)
        throw Exception('The file is not available on Telegram yet.');
      final telegram = ref.read(telegramTransferServiceProvider);
      await telegram.configure(
        backendUserId: '${user.userId}',
        telegramUserId: user.telegramId,
      );
      if (!active()) return;
      final authorized = await telegram.isAuthorized;
      if (!active()) return;
      if (!authorized) {
        reconnect();
        return;
      }
      final result = await telegram.downloadToCache(
        telegramRef,
        filename: file.name,
        cacheKey: media.cacheKey,
      );
      if (!active()) return;
      path = result.file.path;
    } else {
      final url = file.downloadUrl;
      if (url == null)
        throw Exception('A download is not available for this file yet.');
      final directory = await getTemporaryDirectory();
      if (!active()) return;
      final cached = await DownloadCache(directory).obtain(
        backend: AppConfig.storageNamespace,
        userId: user.userId,
        file: file,
        download: (path) async {
          await api.dio.download(url, path);
        },
      );
      if (!active()) return;
      path = cached.path;
    }
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) throw Exception(result.message);
  } catch (error) {
    if (active())
      messenger.showSnackBar(
        SnackBar(
          content: Text(api.errorMessage(error, 'Could not open file.')),
        ),
      );
  }
}
