import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_m_fsdk/core/notifications/upload_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'deferred setup shares in-flight work and retries failure before permission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var attempt = Completer<bool>();
      var initializations = 0;
      var channels = 0;
      var permissions = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'initialize':
            initializations++;
            return attempt.future;
          case 'createNotificationChannel':
            channels++;
            return null;
          case 'requestNotificationsPermission':
            permissions++;
            return true;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final service = UploadNotificationService.instance;
      final first = service.initialize();
      final second = service.initialize();
      expect(identical(first, second), isTrue);
      final failure = expectLater(first, throwsA(isA<PlatformException>()));
      await Future<void>.delayed(Duration.zero);
      attempt.completeError(PlatformException(code: 'fixture-unavailable'));
      await failure;
      expect(initializations, 1);
      expect(channels, 0);

      attempt = Completer<bool>();
      final retry = service.initialize();
      final permission = service.requestPermission();
      await Future<void>.delayed(Duration.zero);
      expect(initializations, 2);
      expect(permissions, 0);
      attempt.complete(true);
      await retry;
      expect(await permission, isTrue);
      expect(channels, 1);
      expect(permissions, 1);
      await service.initialize();
      expect(initializations, 2);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(service.isForeground, isFalse);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(service.isForeground, isTrue);
      WidgetsBinding.instance.removeObserver(service);
    },
  );
}
