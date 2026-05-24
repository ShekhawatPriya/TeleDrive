import 'package:flutter_m_fsdk/features/profile/app_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads production-safe defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppSettingsController();

    await controller.load();

    expect(controller.state.askBeforeLargeUploads, isTrue);
    expect(controller.state.uploadOnMobileData, isTrue);
    expect(controller.state.autoRenameDuplicates, isFalse);
    expect(controller.state.trashEnabled, isTrue);
    expect(controller.state.confirmPublicShares, isFalse);
    expect(controller.state.clearCacheOnSignOut, isTrue);
    expect(controller.state.uploadCompletedAlerts, isFalse);
    expect(controller.state.uploadFailedAlerts, isFalse);
    expect(controller.state.galleryBackupEnabled, isFalse);
    expect(controller.state.galleryBackupWifiOnly, isTrue);
    expect(controller.state.galleryBackupScanLimit, 80);
    expect(controller.state.galleryBackupQueueLimit, 12);
    expect(
      controller.state.galleryBackupIndexingStrategy,
      GalleryBackupIndexingStrategy.mediaStoreOnly,
    );
  });

  test('persists changed settings', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppSettingsController();
    await controller.load();

    await controller.setUploadOnMobileData(false);
    await controller.setAutoRenameDuplicates(true);
    await controller.setGalleryBackupEnabled(true);
    await controller.setGalleryBackupWifiOnly(false);
    await controller.setGalleryBackupScanLimit(140);
    await controller.setGalleryBackupQueueLimit(22);
    await controller.setGalleryBackupIndexingStrategy(
      GalleryBackupIndexingStrategy.mediaStoreAndFilePath,
    );

    final reloaded = AppSettingsController();
    await reloaded.load();

    expect(reloaded.state.uploadOnMobileData, isFalse);
    expect(reloaded.state.autoRenameDuplicates, isTrue);
    expect(reloaded.state.galleryBackupEnabled, isTrue);
    expect(reloaded.state.galleryBackupWifiOnly, isFalse);
    expect(reloaded.state.galleryBackupScanLimit, 140);
    expect(reloaded.state.galleryBackupQueueLimit, 22);
    expect(
      reloaded.state.galleryBackupIndexingStrategy,
      GalleryBackupIndexingStrategy.mediaStoreAndFilePath,
    );
  });

  test(
    'bounds backup scan and queue limits while persisting strategy',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppSettingsController();
      await controller.load();

      await controller.setGalleryBackupScanLimit(9999);
      await controller.setGalleryBackupQueueLimit(0);
      await controller.setGalleryBackupIndexingStrategy(
        GalleryBackupIndexingStrategy.filePathOnly,
      );

      final reloaded = AppSettingsController();
      await reloaded.load();

      expect(reloaded.state.galleryBackupScanLimit, 500);
      expect(reloaded.state.galleryBackupQueueLimit, 1);
      expect(
        reloaded.state.galleryBackupIndexingStrategy,
        GalleryBackupIndexingStrategy.filePathOnly,
      );
    },
  );
}
