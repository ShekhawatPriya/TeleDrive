import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/notifications/upload_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    dotenv.load(fileName: '.env.local'),
    AppConfig.bootstrap(),
  ]);
  runApp(const ProviderScope(child: TeleDriveApp()));
  unawaited(_initializeNotificationsAfterFirstFrame());
}

Future<void> _initializeNotificationsAfterFirstFrame() async {
  await WidgetsBinding.instance.endOfFrame;
  try {
    await UploadNotificationService.instance.initialize();
  } catch (_) {
    // Optional setup must not prevent startup. Permission/show calls await
    // initialization themselves and retry if this attempt failed.
    debugPrint('Notification setup unavailable; will retry when needed.');
  }
}
