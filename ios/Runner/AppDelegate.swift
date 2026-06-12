import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let tdlibBridge = TdlibBridge()
  private let mediaChannelHandler = MediaChannelHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: deliver banners while the app is running.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // App-level channel registration for the UIScene-based template. The
  // pre-scene `window?.rootViewController` approach crashes here — channels
  // must be registered through the implicit-engine bridge instead. This is
  // the MainActivity.configureFlutterEngine analogue.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    let tdlibBridge = self.tdlibBridge
    FlutterMethodChannel(name: "teledrive/tdlib", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        tdlibBridge.handle(call, result: result)
      }
    FlutterEventChannel(name: "teledrive/tdlib/events", binaryMessenger: messenger)
      .setStreamHandler(tdlibBridge)

    let mediaChannelHandler = self.mediaChannelHandler
    FlutterMethodChannel(name: "teledrive/media", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        mediaChannelHandler.handle(call, result: result)
      }
  }
}
