import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/storage/thumbnail_cache_manager.dart';

class CacheState {
  final int totalSize;
  final int thumbnailSize;
  final int previewSize;
  final int originalSize;
  final int uploadStagingSize;
  final int estimatedItems;
  final String status; // Clean, Moderate, Large
  final DateTime? lastScanTime;
  final bool isLoading;
  final bool isClearing;

  const CacheState({
    this.totalSize = 0,
    this.thumbnailSize = 0,
    this.previewSize = 0,
    this.originalSize = 0,
    this.uploadStagingSize = 0,
    this.estimatedItems = 0,
    this.status = 'Clean',
    this.lastScanTime,
    this.isLoading = false,
    this.isClearing = false,
  });

  CacheState copyWith({
    int? totalSize,
    int? thumbnailSize,
    int? previewSize,
    int? originalSize,
    int? uploadStagingSize,
    int? estimatedItems,
    String? status,
    DateTime? lastScanTime,
    bool? isLoading,
    bool? isClearing,
  }) {
    return CacheState(
      totalSize: totalSize ?? this.totalSize,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      previewSize: previewSize ?? this.previewSize,
      originalSize: originalSize ?? this.originalSize,
      uploadStagingSize: uploadStagingSize ?? this.uploadStagingSize,
      estimatedItems: estimatedItems ?? this.estimatedItems,
      status: status ?? this.status,
      lastScanTime: lastScanTime ?? this.lastScanTime,
      isLoading: isLoading ?? this.isLoading,
      isClearing: isClearing ?? this.isClearing,
    );
  }
}

final cacheControllerProvider = ChangeNotifierProvider<CacheController>((ref) {
  return CacheController()..refreshCacheStats();
});

class CacheController extends ChangeNotifier {
  CacheState state = const CacheState();

  Future<void> refreshCacheStats() async {
    if (state.isClearing) return;
    state = state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final tempDir = await getTemporaryDirectory();
      if (!await tempDir.exists()) {
        state = state.copyWith(
          totalSize: 0,
          thumbnailSize: 0,
          previewSize: 0,
          originalSize: 0,
          uploadStagingSize: 0,
          estimatedItems: 0,
          status: 'Clean',
          lastScanTime: DateTime.now(),
          isLoading: false,
        );
        notifyListeners();
        return;
      }

      int total = 0;
      int thumbnail = 0;
      int preview = 0;
      int original = 0;
      int staging = 0;
      int itemsCount = 0;

      final tempPath = tempDir.path;

      final stream = tempDir.list(recursive: true, followLinks: false);
      await for (final entity in stream) {
        if (entity is File) {
          try {
            final size = await entity.length();
            total += size;
            itemsCount++;

            final path = entity.path.toLowerCase();
            final parentPath = entity.parent.path;

            // 1. Thumbnail Cache: inside teledriveThumbnailCache or libCachedImageData
            if (path.contains('teledrivethumbnailcache') || path.contains('libcachedimagedata')) {
              thumbnail += size;
            }
            // 2. Upload Staging / Picker temporary files: contains file_picker, image_picker or ends with .tmp / .bin
            else if (path.contains('file_picker') ||
                path.contains('image_picker') ||
                path.endsWith('.tmp') ||
                path.endsWith('.bin')) {
              staging += size;
            }
            // 3. Cached Originals/Downloaded files: direct children in temp directory root
            else if (parentPath == tempPath) {
              original += size;
            }
            // 4. Preview Cache: general preview chunks or cached streams
            else {
              preview += size;
            }
          } catch (_) {
            // File might have been deleted/locked during scanning
          }
        }
      }

      String healthStatus = 'Clean';
      if (total > 500 * 1024 * 1024) {
        // > 500MB
        healthStatus = 'Large';
      } else if (total > 50 * 1024 * 1024) {
        // > 50MB
        healthStatus = 'Moderate';
      }

      state = state.copyWith(
        totalSize: total,
        thumbnailSize: thumbnail,
        previewSize: preview,
        originalSize: original,
        uploadStagingSize: staging,
        estimatedItems: itemsCount,
        status: healthStatus,
        lastScanTime: DateTime.now(),
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error scanning cache: $e');
      state = state.copyWith(isLoading: false);
    }
    notifyListeners();
  }

  Future<void> clearCache() async {
    if (state.isClearing) return;
    state = state.copyWith(isClearing: true);
    notifyListeners();

    try {
      // 1. Empty cache manager
      try {
        await TeleDriveThumbnailCacheManager.instance.emptyCache();
      } catch (e) {
        debugPrint('Error clearing TeleDriveThumbnailCacheManager: $e');
      }

      // 2. Delete all other files in temporary directory safely
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final stream = tempDir.list(recursive: false, followLinks: false);
        await for (final entity in stream) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            debugPrint('Error deleting cache entity ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache directory: $e');
    }

    state = state.copyWith(isClearing: false);
    await refreshCacheStats();
  }
}
