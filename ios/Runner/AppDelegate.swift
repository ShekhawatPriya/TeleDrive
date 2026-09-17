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
    engineBridge.applicationRegistrar.register(
      ItemContextMenuFactory(messenger: messenger), withId: "teledrive/item-context-menu")
    FlutterMethodChannel(name: "teledrive/appearance", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        if call.method == "supportsContextMenus" { result(true) }
        else if call.method == "supportsNativeTabs" { result(true) }
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
      else { configuration.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: CGFloat(args["symbolSize"] as? Double ?? 19), weight: .semibold)) }
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


/// Context interactions live on lazy, transparent tile hit regions. The native
/// preview uses an ephemeral thumbnail snapshot, never network or file access.
final class ItemContextMenuFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    ItemContextMenuView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

final class ItemContextMenuView: NSObject, FlutterPlatformView, UIContextMenuInteractionDelegate {
  private let surface = ContextHitSurface()
  private let channel: FlutterMethodChannel
  private var identity = ""
  private var title = ""
  private var generation = 0
  private var interaction: UIContextMenuInteraction!
  private var preview: ContextPreviewController?
  private var pendingAction: (identity: String, id: String)?
  private var menuPresented = false
  private var activeIdentity: String?
  private var sourceImage: UIImage?

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/item-context-menu/\(id)", binaryMessenger: messenger)
    super.init()
    surface.frame = frame
    surface.backgroundColor = .clear
    surface.onTouchBegan = { [weak self] in self?.prepareSnapshot() }
    interaction = UIContextMenuInteraction(delegate: self)
    surface.addInteraction(interaction)
    surface.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(open)))
    update(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update" { self?.update(call.arguments); result(nil) }
      else { result(FlutterMethodNotImplemented) }
    }
  }
  func view() -> UIView { surface }
  private func update(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    let next = args["identity"] as? String ?? ""
    if next != identity {
      generation += 1
      pendingAction = nil
      interaction?.dismissMenu()
      preview = nil
      sourceImage = nil
    }
    identity = next
    title = args["title"] as? String ?? ""
    surface.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
  }
  @objc private func open() { channel.invokeMethod("open", arguments: identity) }

  private func prepareSnapshot() {
    let itemID = identity
    let requestGeneration = generation
    channel.invokeMethod("previewRequest", arguments: itemID) { [weak self] result in
      guard let self = self, self.generation == requestGeneration, self.identity == itemID,
            let bytes = result as? FlutterStandardTypedData, let image = UIImage(data: bytes.data) else { return }
      self.sourceImage = image
      self.preview?.setImage(image)
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
        if self?.activeIdentity == nil { self?.sourceImage = nil }
      }
    }
  }

  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
    targetedPreview()
  }
  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
    targetedPreview()
  }
  @available(iOS 16.0, *)
  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configuration: UIContextMenuConfiguration, highlightPreviewForItemWithIdentifier identifier: NSCopying) -> UITargetedPreview? {
    targetedPreview()
  }
  @available(iOS 16.0, *)
  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configuration: UIContextMenuConfiguration, dismissalPreviewForItemWithIdentifier identifier: NSCopying) -> UITargetedPreview? {
    targetedPreview()
  }
  private func targetedPreview() -> UITargetedPreview? {
    guard let image = sourceImage, surface.window != nil else { return nil }
    let imageView = UIImageView(image: image)
    imageView.frame = surface.bounds
    imageView.contentMode = .scaleAspectFit
    let parameters = UIPreviewParameters()
    parameters.backgroundColor = .clear
    parameters.visiblePath = UIBezierPath(roundedRect: surface.bounds, cornerRadius: 16)
    let target = UIPreviewTarget(container: surface, center: CGPoint(x: surface.bounds.midX, y: surface.bounds.midY))
    return UITargetedPreview(view: imageView, parameters: parameters, target: target)
  }

  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    let itemID = identity
    activeIdentity = itemID
    menuPresented = true
    pendingAction = nil
    let controller = ContextPreviewController(title: title, sourceSize: surface.bounds.size)
    controller.overrideUserInterfaceStyle = surface.overrideUserInterfaceStyle
    preview = controller
    if let image = sourceImage { controller.setImage(image) }
    else { prepareSnapshot() }
    return UIContextMenuConfiguration(identifier: itemID as NSString, previewProvider: { controller }) { [weak self] _ in
      UIMenu(children: [UIDeferredMenuElement.uncached { completion in
        guard let self = self else { completion([]); return }
        self.channel.invokeMethod("menuRequest", arguments: itemID) { [weak self] result in
          guard let self = self, self.identity == itemID,
                let sections = result as? [[String: Any]] else { completion([]); return }
          completion(sections.map { section in
            let actions = (section["items"] as? [[String: Any]] ?? []).map { item in
              UIAction(title: item["label"] as? String ?? "", image: UIImage(systemName: item["symbol"] as? String ?? ""),
                attributes: (item["destructive"] as? Bool ?? false) ? .destructive : [],
                state: (item["checked"] as? Bool ?? false) ? .on : .off) { [weak self] _ in
                  guard let self = self, let id = item["id"] as? String else { return }
                  self.pendingAction = (itemID, id)
                  if !self.menuPresented { self.deliverAction() }
                }
            }
            return UIMenu(title: "", options: .displayInline, children: actions)
          })
        }
      }])
    }
  }

  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
    let itemID = identity
    animator.addCompletion { [weak self] in
      guard let self = self, self.identity == itemID else { return }
      self.channel.invokeMethod("open", arguments: itemID)
    }
  }

  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
    channel.invokeMethod("visibility", arguments: ["identity": identity, "visible": true])
  }

  private func deliverAction() {
    guard let action = pendingAction else { return }
    pendingAction = nil
    guard identity == action.identity else { return }
    channel.invokeMethod("menuAction", arguments: ["identity": action.identity, "id": action.id])
  }

  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
    let finish = { [weak self] in
      guard let self = self else { return }
      self.menuPresented = false
      if let itemID = self.activeIdentity {
        self.channel.invokeMethod("visibility", arguments: ["identity": itemID, "visible": false])
      }
      self.deliverAction()
      self.activeIdentity = nil
      self.preview = nil
      self.sourceImage = nil
    }
    if let animator = animator { animator.addCompletion(finish) }
    else { finish() }
  }
  deinit { channel.setMethodCallHandler(nil) }
}

private final class ContextPreviewController: UIViewController {
  private let imageView = UIImageView()
  private let nameLabel = UILabel()
  init(title: String, sourceSize: CGSize) {
    super.init(nibName: nil, bundle: nil)
    nameLabel.text = title
    let width: CGFloat = min(360, max(240, sourceSize.width))
    let ratio = sourceSize.width > 0 ? sourceSize.height / sourceSize.width : 1
    preferredContentSize = CGSize(width: width, height: min(420, max(88, width * ratio)))
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func loadView() {
    view = UIView()
    view.backgroundColor = .secondarySystemBackground
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    nameLabel.font = .preferredFont(forTextStyle: .body)
    nameLabel.adjustsFontForContentSizeCategory = true
    nameLabel.numberOfLines = 0
    nameLabel.textAlignment = .center
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(imageView)
    view.addSubview(nameLabel)
    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor), imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      imageView.topAnchor.constraint(equalTo: view.topAnchor), imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16), nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      nameLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
    ])
  }
  func setImage(_ image: UIImage) {
    loadViewIfNeeded()
    imageView.image = image
    nameLabel.isHidden = true
  }
}


private final class ContextHitSurface: UIView {
  var onTouchBegan: (() -> Void)?
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    onTouchBegan?()
    super.touchesBegan(touches, with: event)
  }
}
