import 'dart:io';
import '../../models/drive_models.dart';
import '../utils/stable_hash.dart';

/// Account- and revision-scoped paths prevent same-name downloads opening a
/// different file. Only a fully downloaded file is promoted into the cache.
class DownloadCache {
  DownloadCache(this.root);
  final Directory root;

  String relativePath(String backend, int userId, DriveFile file) {
    final name = file.name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .trim();
    final safeName = name.isEmpty || name == '.' || name == '..'
        ? 'download'
        : name;
    final revision = stableHash(
      '$backend:$userId:${file.id}:${file.modifiedAt}:${file.size}',
    );
    return 'teledrive-downloads/$revision/$safeName';
  }

  Future<File> obtain({
    required String backend,
    required int userId,
    required DriveFile file,
    required Future<void> Function(String path) download,
  }) async {
    final target = File('${root.path}/${relativePath(backend, userId, file)}');
    if (await target.exists() &&
        (file.size <= 0 || await target.length() == file.size))
      return target;
    await target.parent.create(recursive: true);
    final staging = await target.parent.createTemp('.download-');
    final partial = File('${staging.path}/payload');
    try {
      await download(partial.path);
      if (file.size > 0 && await partial.length() != file.size)
        throw const FileSystemException(
          'Download is incomplete. Please try again.',
        );
      if (await target.exists()) await target.delete();
      return await partial.rename(target.path);
    } finally {
      if (await partial.exists()) await partial.delete();
      if (await staging.exists()) await staging.delete();
    }
  }
}
