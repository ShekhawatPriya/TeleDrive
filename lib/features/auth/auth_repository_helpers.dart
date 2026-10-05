part of 'auth_repository.dart';

extension _AuthRepositoryHelpers on AuthRepository {
  AuthUser _withLoadablePhotoUrl(AuthUser user, {String? tokenOverride}) {
    final photoUrl = user.photoUrl?.trim();
    if (photoUrl == null || photoUrl.isEmpty || photoUrl.startsWith('data:')) {
      return user;
    }
    final uri = Uri.tryParse(photoUrl);
    if (uri != null && uri.hasScheme) return user;
    return user.copyWith(
      photoUrl: api.mediaUrl(
        photoUrl,
        params: {if (tokenOverride != null) 'token': tokenOverride},
      ),
    );
  }

  List<CommunityTarget> _communityTargets(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => CommunityTarget.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<Directory> _profilePhotoDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}teledrive${Platform.pathSeparator}profile_photos${Platform.pathSeparator}${stableHash(AppConfig.storageNamespace)}',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  List<int>? _decodeDataImage(String source) {
    final comma = source.indexOf(',');
    if (comma == -1) return null;
    return base64Decode(source.substring(comma + 1));
  }

  Future<List<int>?> _downloadProfilePhoto(String source) async {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
    try {
      final response = await client.get<List<int>>(
        source,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data;
    } finally {
      client.close();
    }
  }

  Future<void> _deleteCachedProfilePhotoFiles(int userId) async {
    final dir = await _profilePhotoDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path
          : entity.uri.pathSegments.last;
      if (name == '$userId.jpg' || name.startsWith('${userId}_')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  bool _isLocalPath(String value) {
    if (value.startsWith('file://')) return true;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme.isNotEmpty) return false;
    return value.startsWith('/') || RegExp(r'^[A-Za-z]:\\').hasMatch(value);
  }
}
