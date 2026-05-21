import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final uploadNotificationServiceProvider = Provider<UploadNotificationService>(
  (ref) => UploadNotificationService.instance,
);

class UploadNotificationService with WidgetsBindingObserver {
  UploadNotificationService._();

  static final UploadNotificationService instance =
      UploadNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  Future<void> initialize() async {
    if (_initialized) return;
    WidgetsBinding.instance.addObserver(this);
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    const channel = AndroidNotificationChannel(
      'upload_status',
      'Upload status',
      description: 'Upload completion and failure alerts',
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  bool get isForeground => _lifecycleState == AppLifecycleState.resumed;

  Future<void> showUploadComplete({
    required int total,
    required int failed,
  }) async {
    await _show(
      id: 1001,
      title: failed == 0 ? 'Upload complete' : 'Upload finished',
      body: failed == 0
          ? '$total ${total == 1 ? 'file' : 'files'} uploaded successfully.'
          : '${total - failed} uploaded, $failed failed.',
    );
  }

  Future<void> showUploadFailed({required int failed}) async {
    await _show(
      id: 1002,
      title: 'Upload failed',
      body: '$failed ${failed == 1 ? 'file' : 'files'} could not be uploaded.',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (isForeground) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'upload_status',
        'Upload status',
        channelDescription: 'Upload completion and failure alerts',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }
}
