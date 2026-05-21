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
  });

  test('persists changed settings', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppSettingsController();
    await controller.load();

    await controller.setUploadOnMobileData(false);
    await controller.setAutoRenameDuplicates(true);

    final reloaded = AppSettingsController();
    await reloaded.load();

    expect(reloaded.state.uploadOnMobileData, isFalse);
    expect(reloaded.state.autoRenameDuplicates, isTrue);
  });
}
