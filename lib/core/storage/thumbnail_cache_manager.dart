import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class TeleDriveThumbnailCacheManager {
  static const key = 'teledriveThumbnailCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 3000,
    ),
  );
}
