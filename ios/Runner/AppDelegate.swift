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
    engineBridge.applicationRegistrar.register(
      GlassButtonFactory(messenger: messenger), withId: "teledrive/glass-button")
    engineBridge.applicationRegistrar.register(
      NativeTabBarFactory(messenger: messenger), withId: "teledrive/tab-bar")
    FlutterMethodChannel(name: "teledrive/appearance", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        if call.method == "supportsNativeTabs" { result(true) }
        else if call.method == "supportsGlass" {
          if #available(iOS 26.0, *) { result(true) } else { result(false) }
        } else { result(FlutterMethodNotImplemented) }
      }

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

/// System-rendered controls keep Liquid Glass and accessibility preferences
/// owned by UIKit. File content never crosses this platform-view bridge.
final class GlassButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassButtonView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

final class GlassButtonView: NSObject, FlutterPlatformView {
  private let button = UIButton(type: .system)
  private let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/glass-button/\(id)", binaryMessenger: messenger)
    super.init()
    button.frame = frame
    update(arguments)
    button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update" { self?.update(call.arguments); result(nil) }
      else { result(FlutterMethodNotImplemented) }
    }
  }
  func view() -> UIView { button }
  private func update(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    let label = args["label"] as? String ?? ""
    let symbol = args["symbol"] as? String ?? ""
    let prominent = args["prominent"] as? Bool ?? false
    button.accessibilityLabel = label
    button.isEnabled = args["enabled"] as? Bool ?? true
    button.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
    button.tintColor = (args["white"] as? Bool ?? false) ? .white : .label
    let hasMenu = args["hasMenu"] as? Bool ?? false
    button.showsMenuAsPrimaryAction = hasMenu
    if hasMenu {
      button.menu = UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] completion in
        guard let self = self else { completion([]); return }
        self.channel.invokeMethod("menuRequest", arguments: nil) { [weak self] result in
          guard let self = self, let sections = result as? [[String: Any]] else {
            completion([]); return
          }
          let menus = sections.map { section -> UIMenu in
            let items = section["items"] as? [[String: Any]] ?? []
            let actions = items.map { item -> UIAction in
              let id = item["id"] as? String ?? ""
              let action = UIAction(
                title: item["label"] as? String ?? "",
                image: UIImage(systemName: item["symbol"] as? String ?? ""),
                attributes: (item["destructive"] as? Bool ?? false) ? .destructive : [],
                state: (item["checked"] as? Bool ?? false) ? .on : .off
              ) { [weak self] _ in self?.channel.invokeMethod("menuAction", arguments: id) }
              action.subtitle = item["subtitle"] as? String
              return action
            }
            let title = section["title"] as? String ?? ""
            let symbol = section["symbol"] as? String ?? ""
            return UIMenu(title: title, image: UIImage(systemName: symbol),
              options: title.isEmpty ? .displayInline : [], children: actions)
          }
          completion(menus)
        }
      }])
    } else { button.menu = nil }
    if #available(iOS 26.0, *) {
      var configuration: UIButton.Configuration = prominent ? .prominentGlass() : .glass()
      configuration.cornerStyle = .capsule
      let textScale = args["textScale"] as? Double ?? 1
      configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
        var updated = attributes
        updated.font = UIFont.systemFont(ofSize: 17 * textScale, weight: .semibold)
        return updated
      }
      if symbol.isEmpty { configuration.title = label }
      else { configuration.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold)) }
      button.configuration = configuration
    } else {
      if symbol.isEmpty { button.setTitle(label, for: .normal) }
      else { button.setImage(UIImage(systemName: symbol), for: .normal) }
    }
  }
  @objc private func tapped() { if !button.showsMenuAsPrimaryAction { channel.invokeMethod("tap", arguments: nil) } }
  deinit { channel.setMethodCallHandler(nil) }
}


/// A system tab bar; UIKit owns the Liquid Glass lens, SF Symbols and selection.
final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeTabBarView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}
final class NativeTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let bar = UITabBar()
  private let channel: FlutterMethodChannel
  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/tab-bar/\(id)", binaryMessenger: messenger)
    super.init()
    bar.frame = frame
    let labels = ["Drive", "Photos", "Starred", "Shared"]
    let symbols = ["folder", "photo.on.rectangle", "star", "person.2"]
    let selected = ["folder.fill", "photo.on.rectangle.fill", "star.fill", "person.2.fill"]
    bar.items = labels.enumerated().map { index, label in
      let item = UITabBarItem(title: label, image: UIImage(systemName: symbols[index]), selectedImage: UIImage(systemName: selected[index]))
      item.tag = index
      item.accessibilityIdentifier = "teledrive.tab.\(index)"
      return item
    }
    bar.delegate = self
    bar.isTranslucent = true
    update(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update" { self?.update(call.arguments); result(nil) }
      else { result(FlutterMethodNotImplemented) }
    }
  }
  func view() -> UIView { bar }
  private func update(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    bar.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
    bar.tintColor = .systemBlue
    let index = args["selectedIndex"] as? Int ?? 0
    if let items = bar.items, items.indices.contains(index) { bar.selectedItem = items[index] }
  }
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("select", arguments: item.tag)
  }
  deinit { channel.setMethodCallHandler(nil) }
}
