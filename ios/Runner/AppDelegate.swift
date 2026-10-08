import Flutter
import UIKit
import QuickLookThumbnailing
import ImageIO
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let tdlibBridge = TdlibBridge()
  private let uploadSourceChooser = UploadSourceChooser()
  private let mediaChannelHandler = MediaChannelHandler()
  private var accessibilityPreferences: AccessibilityPreferences?

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
      PhotoVideoFactory(messenger: messenger), withId: "teledrive/photo-video")
    accessibilityPreferences = AccessibilityPreferences(messenger: messenger)
    engineBridge.applicationRegistrar.register(
      GlassButtonFactory(messenger: messenger), withId: "teledrive/glass-button")
    engineBridge.applicationRegistrar.register(
      NativeTabBarFactory(messenger: messenger), withId: "teledrive/tab-bar")
    engineBridge.applicationRegistrar.register(
      ItemContextMenuFactory(messenger: messenger), withId: "teledrive/item-context-menu")
    engineBridge.applicationRegistrar.register(
      SelectionToolbarFactory(messenger: messenger), withId: "teledrive/selection-toolbar")
    engineBridge.applicationRegistrar.register(
      NativeSearchFactory(messenger: messenger), withId: "teledrive/search")
    engineBridge.applicationRegistrar.register(
      PhotosLibraryControlsFactory(messenger: messenger), withId: "teledrive/photos-controls")
    FlutterMethodChannel(name: "teledrive/appearance", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        if call.method == "chooseUploadSource" { self.uploadSourceChooser.show(call.arguments, result: result) }
        else if call.method == "dismissKeyboard" {
          UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }.forEach { $0.endEditing(true) }
          result(nil)
        }
        else if call.method == "supportsPhotoVideo" { result(true) }
        else if call.method == "supportsNativeSearch" { result(true) }
        else if call.method == "supportsPhotosControls" { result(true) }
        else if call.method == "supportsContextMenus" { result(true) }
        else if call.method == "supportsSelectionToolbar" { result(true) }
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

/// UIKit owns the preference; Flutter receives both the initial value and live changes.
final class AccessibilityPreferences: NSObject {
  private let channel: FlutterMethodChannel
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/accessibility", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { call, result in
      if call.method == "getReduceTransparency" { result(UIAccessibility.isReduceTransparencyEnabled) }
      else { result(FlutterMethodNotImplemented) }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(changed),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
  }
  @objc private func changed() {
    channel.invokeMethod("reduceTransparencyChanged", arguments: UIAccessibility.isReduceTransparencyEnabled)
  }
  deinit { NotificationCenter.default.removeObserver(self); channel.setMethodCallHandler(nil) }
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

/// Revoke uses the system chain artwork with a simple slash. SF Symbols has
/// no link-off symbol on every supported iOS version, so return a tintable
/// template rather than requesting an unavailable symbol.
private func nativeActionImage(_ symbol: String, configuration: UIImage.SymbolConfiguration? = nil) -> UIImage? {
  guard symbol == "teledrive.link-off" else {
    return UIImage(systemName: symbol, withConfiguration: configuration)
  }
  guard let link = UIImage(systemName: "link", withConfiguration: configuration) else { return nil }
  let size = link.size
  let image = UIGraphicsImageRenderer(size: size).image { renderer in
    link.withTintColor(.black, renderingMode: .alwaysOriginal).draw(at: .zero)
    let context = renderer.cgContext
    let start = CGPoint(x: size.width * 0.12, y: size.height * 0.08)
    let end = CGPoint(x: size.width * 0.88, y: size.height * 0.92)
    context.setLineCap(.round)
    // Clear a narrow halo so the slash remains readable over the chain.
    context.setBlendMode(.clear)
    context.setLineWidth(size.height * 0.17)
    context.move(to: start); context.addLine(to: end); context.strokePath()
    context.setBlendMode(.normal)
    context.setStrokeColor(UIColor.black.cgColor)
    context.setLineWidth(size.height * 0.08)
    context.move(to: start); context.addLine(to: end); context.strokePath()
  }
  return image.withRenderingMode(.alwaysTemplate)
}

final class GlassButtonView: NSObject, FlutterPlatformView {
  private let button = UIButton(type: .system)
  private let channel: FlutterMethodChannel
  private var lastArguments: NSDictionary?
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
    let snapshot = args as NSDictionary
    guard lastArguments?.isEqual(snapshot) != true else { return }
    lastArguments = snapshot
    let label = args["label"] as? String ?? ""
    let symbol = args["symbol"] as? String ?? ""
    let prominent = args["prominent"] as? Bool ?? false
    button.accessibilityLabel = label
    button.isEnabled = args["enabled"] as? Bool ?? true
    button.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
    let plain = args["plain"] as? Bool ?? false
    button.tintColor = plain
      ? Self.color(argb: args["tint"] as? Int) ?? .secondaryLabel
      : (args["white"] as? Bool ?? false) ? .white : .label
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
                image: nativeActionImage(item["symbol"] as? String ?? ""),
                attributes: (item["destructive"] as? Bool ?? false) ? .destructive : [],
                state: (item["checked"] as? Bool ?? false) ? .on : .off
              ) { [weak self] _ in self?.channel.invokeMethod("menuAction", arguments: id) }
              if #available(iOS 16.0, *) { action.subtitle = item["subtitle"] as? String }
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
      // `plain` is a bare glyph with no glass, used for per-row overflow so
      // rows match the Flutter ellipsis on Drive rows.
      var configuration: UIButton.Configuration = plain ? .plain() : prominent ? .prominentGlass() : .glass()
      configuration.cornerStyle = .capsule
      if plain { configuration.contentInsets = .zero }
      if let visual = args["visualSize"] as? Double, visual < 44, !plain {
        let inset = (44 - visual) / 2
        configuration.background.backgroundInsets = NSDirectionalEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
      }
      if prominent {
        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in .white }
      }
      let textScale = args["textScale"] as? Double ?? 1
      configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
        var updated = attributes
        updated.font = UIFont.systemFont(ofSize: 17 * textScale, weight: .semibold)
        return updated
      }
      if symbol.isEmpty { configuration.title = label }
      else { configuration.image = nativeActionImage(symbol, configuration: UIImage.SymbolConfiguration(pointSize: CGFloat(args["symbolSize"] as? Double ?? 19), weight: Self.weight(args["symbolWeight"] as? String))) }
      button.configuration = configuration
    } else {
      if symbol.isEmpty { button.setTitle(label, for: .normal) }
      else { button.setImage(nativeActionImage(symbol), for: .normal) }
    }
  }
  private static func weight(_ name: String?) -> UIImage.SymbolWeight {
    switch name {
    case "regular": return .regular
    case "medium": return .medium
    default: return .semibold
    }
  }
  private static func color(argb: Int?) -> UIColor? {
    guard let argb = argb else { return nil }
    return UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255, alpha: CGFloat((argb >> 24) & 0xFF) / 255)
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
  private let root = TabBarLayoutView()
  private var selectedIndex = 0
  private let channel: FlutterMethodChannel
  private var lastArguments: NSDictionary?
  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/tab-bar/\(id)", binaryMessenger: messenger)
    super.init()
    root.frame = frame
    root.addSubview(bar)
    root.onLayout = { [weak self] in self?.layoutBar() }
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
  func view() -> UIView { root }
  private func layoutBar() {
    guard root.bounds.width > 0, root.bounds.height > 0 else { return }
    UIView.performWithoutAnimation {
      // Use UIKit's fitted height instead of stretching its selection lens to
      // Flutter's reserved footer height. Keep the native safe-area inset.
      let height = min(root.bounds.height, bar.sizeThatFits(root.bounds.size).height)
      bar.frame = CGRect(x: 0, y: root.bounds.height - height,
        width: root.bounds.width, height: height)
      bar.layoutIfNeeded()
      if let items = bar.items, items.indices.contains(selectedIndex),
         bar.selectedItem !== items[selectedIndex] {
        bar.selectedItem = items[selectedIndex]
        bar.layoutIfNeeded()
      }
    }
  }
  private func update(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    let snapshot = args as NSDictionary
    guard lastArguments?.isEqual(snapshot) != true else { return }
    lastArguments = snapshot
    root.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
    bar.tintColor = .systemBlue
    selectedIndex = args["selectedIndex"] as? Int ?? 0
    // Wait for a real platform-view frame before creating the selection lens.
    // Loading/provider rebuilds must not restart its selection animation.
    layoutBar()
  }
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    selectedIndex = item.tag
    channel.invokeMethod("select", arguments: item.tag)
  }
  deinit { channel.setMethodCallHandler(nil) }
}

private final class TabBarLayoutView: UIView {
  var onLayout: (() -> Void)?
  override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
  override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); setNeedsLayout() }
}


/// Context interactions live on lazy, transparent tile hit regions. Source
/// snapshots animate the lift; scoped local content supplies the actual preview.
/// All network/media access stays behind the Dart media services.
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
  private var subtitle = "", symbol = "doc", revision = ""
  private var visualPreview = false
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
    let nextRevision = args["revision"] as? String ?? ""
    if next != identity || nextRevision != revision {
      generation += 1
      pendingAction = nil
      interaction?.dismissMenu()
      preview = nil
      sourceImage = nil
    }
    identity = next
    title = args["title"] as? String ?? ""
    subtitle = args["subtitle"] as? String ?? ""
    symbol = args["symbol"] as? String ?? "doc"
    visualPreview = args["visualPreview"] as? Bool ?? false
    revision = nextRevision
    surface.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
  }
  @objc private func open() {
    guard !menuPresented else { return }
    channel.invokeMethod("open", arguments: identity)
  }

  private func prepareSnapshot() {
    let itemID = identity
    let requestGeneration = generation
    channel.invokeMethod("snapshotRequest", arguments: itemID) { [weak self] result in
      guard let self = self, self.generation == requestGeneration, self.identity == itemID,
            let bytes = result as? FlutterStandardTypedData, let image = UIImage(data: bytes.data) else { return }
      self.sourceImage = image
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
    let controller = ContextPreviewController(title: title, subtitle: subtitle, symbol: symbol,
      visual: visualPreview, availableSize: surface.window?.bounds.size ?? CGSize(width: 390, height: 844))
    controller.overrideUserInterfaceStyle = surface.overrideUserInterfaceStyle
    preview = controller
    let requestGeneration = generation
    channel.invokeMethod("previewRequest", arguments: itemID) { [weak self, weak controller] result in
      guard let self = self, self.generation == requestGeneration, self.activeIdentity == itemID,
            let controller = controller else { return }
      controller.loadPreview(result as? [String: String])
    }
    if sourceImage == nil { prepareSnapshot() }
    return UIContextMenuConfiguration(identifier: itemID as NSString, previewProvider: { controller }) { [weak self] _ in
      UIMenu(children: [UIDeferredMenuElement.uncached { completion in
        guard let self = self else { completion([]); return }
        self.channel.invokeMethod("menuRequest", arguments: itemID) { [weak self] result in
          guard let self = self, self.identity == itemID,
                let sections = result as? [[String: Any]] else { completion([]); return }
          completion(sections.map { section in
            let actions = (section["items"] as? [[String: Any]] ?? []).map { item in
              UIAction(title: item["label"] as? String ?? "", image: nativeActionImage(item["symbol"] as? String ?? ""),
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
    // Hide Flutter only when a real source snapshot can replace it.
    channel.invokeMethod("visibility", arguments: ["identity": identity, "visible": sourceImage != nil])
  }

  private func deliverAction() {
    guard let action = pendingAction else { return }
    pendingAction = nil
    guard identity == action.identity else { return }
    channel.invokeMethod("menuAction", arguments: ["identity": action.identity, "id": action.id])
  }

  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
    // The targeted preview is a detached snapshot, not the Flutter source.
    // Restore that source at the start of dismissal so UIKit never animates
    // back into an empty row while Flutter waits for the completion callback.
    if let itemID = activeIdentity {
      channel.invokeMethod("visibility", arguments: ["identity": itemID, "visible": false])
      channel.invokeMethod("previewCancel", arguments: itemID)
    }
    // Stop loading while retaining the displayed image for UIKit's animation.
    preview?.cancel(clearImage: false)
    let finish = { [weak self] in
      guard let self = self else { return }
      self.menuPresented = false
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
  private let identityStack = UIStackView()
  private let statusLabel = UILabel()
  private let name: String
  private let metadata: String
  private let symbol: String
  private let visual: Bool
  private let availableSize: CGSize
  private var request: QLThumbnailGenerator.Request?
  private var cancelled = false

  init(title: String, subtitle: String, symbol: String, visual: Bool, availableSize: CGSize) {
    name = title; metadata = subtitle; self.symbol = symbol
    self.visual = visual; self.availableSize = availableSize
    super.init(nibName: nil, bundle: nil)
    let width = min(420, availableSize.width - 32)
    preferredContentSize = CGSize(width: width, height: visual ? min(width, availableSize.height * 0.43) : 180)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func loadView() {
    view = UIView()
    view.backgroundColor = .secondarySystemBackground
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.isAccessibilityElement = true
    imageView.accessibilityLabel = name
    imageView.accessibilityIdentifier = "teledrive.context.preview.image"
    imageView.isHidden = true
    let icon = UIImageView(image: UIImage(systemName: symbol))
    icon.contentMode = .scaleAspectFit
    icon.tintColor = .systemBlue
    icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
    let nameLabel = UILabel()
    nameLabel.text = name
    nameLabel.font = .preferredFont(forTextStyle: .headline)
    nameLabel.adjustsFontForContentSizeCategory = true
    nameLabel.numberOfLines = 3
    nameLabel.lineBreakMode = .byTruncatingMiddle
    nameLabel.textAlignment = .center
    let detail = UILabel()
    detail.text = metadata
    detail.font = .preferredFont(forTextStyle: .caption1)
    detail.adjustsFontForContentSizeCategory = true
    detail.textColor = .secondaryLabel
    detail.textAlignment = .center
    statusLabel.text = visual ? "Loading preview…" : "Preview unavailable"
    statusLabel.font = .preferredFont(forTextStyle: .caption1)
    statusLabel.textColor = .secondaryLabel
    statusLabel.textAlignment = .center
    statusLabel.accessibilityIdentifier = "teledrive.context.preview.status"
    identityStack.axis = .vertical
    identityStack.spacing = 8
    identityStack.translatesAutoresizingMaskIntoConstraints = false
    [icon, nameLabel, detail, statusLabel].forEach { identityStack.addArrangedSubview($0) }
    view.addSubview(imageView)
    view.addSubview(identityStack)
    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor), imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      imageView.topAnchor.constraint(equalTo: view.topAnchor), imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      identityStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), identityStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      identityStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      identityStack.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 16),
      identityStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
    ])
  }
  func loadPreview(_ payload: [String: String]?) {
    guard !cancelled else { return }
    loadViewIfNeeded()
    if let path = payload?["imagePath"] {
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: 1200, kCGImageSourceCreateThumbnailWithTransform: true]
        let cgImage = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary) }
        DispatchQueue.main.async {
          guard let self = self, !self.cancelled else { return }
          if let cgImage = cgImage { self.setImage(UIImage(cgImage: cgImage)) }
          else { self.unavailable() }
        }
      }
    } else if let path = payload?["documentPath"] {
      let request = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: path),
        size: CGSize(width: 720, height: 900), scale: 1, representationTypes: .thumbnail)
      self.request = request
      QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
        DispatchQueue.main.async {
          guard let self = self, !self.cancelled else { return }
          if let image = representation?.uiImage { self.setImage(image) }
          else { self.unavailable() }
        }
      }
    } else { unavailable() }
  }
  private func unavailable() {
    statusLabel.text = "Preview unavailable"
    let height = identityStack.systemLayoutSizeFitting(CGSize(width: preferredContentSize.width - 40,
      height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel).height + 40
    preferredContentSize.height = max(180, height)
  }
  private func setImage(_ image: UIImage) {
    guard !cancelled else { return }
    loadViewIfNeeded()
    imageView.image = image
    imageView.isHidden = false
    identityStack.isHidden = true
    let width = min(420, availableSize.width - 32)
    let ratio = image.size.height / max(1, image.size.width)
    let height = min(availableSize.height * 0.48, max(160, width * ratio))
    // Fit the card itself to portrait pages instead of adding empty sidebars.
    preferredContentSize = CGSize(width: min(width, height / ratio), height: height)
  }
  func cancel(clearImage: Bool = true) {
    cancelled = true
    if let request = request { QLThumbnailGenerator.shared.cancel(request) }
    if clearImage { imageView.image = nil }
  }
  deinit { if let request = request { QLThumbnailGenerator.shared.cancel(request) } }
}


private final class ContextHitSurface: UIView {
  var onTouchBegan: (() -> Void)?
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    onTouchBegan?()
    super.touchesBegan(touches, with: event)
  }
}

/// Flexible space separates the primary action capsule from the overflow button
/// under UIKit's toolbar design. The system owns glass, layout and VoiceOver.
final class SelectionToolbarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    SelectionToolbarView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}
final class SelectionToolbarView: NSObject, FlutterPlatformView {
  private let bar = UIToolbar()
  private let channel: FlutterMethodChannel
  private var lastArguments: NSDictionary?
  private var actionItems: [UIBarButtonItem] = []
  private var actionLabels: [String] = []
  private var photoControls = false
  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/selection-toolbar/\(id)", binaryMessenger: messenger)
    super.init()
    bar.frame = frame
    bar.isTranslucent = true
    bar.tintColor = .label
    update(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update" { self?.update(call.arguments); result(nil) }
      else { result(FlutterMethodNotImplemented) }
    }
  }
  func view() -> UIView { bar }
  private func update(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    let snapshot = args as NSDictionary
    guard lastArguments?.isEqual(snapshot) != true else { return }
    let previous = lastArguments
    lastArguments = snapshot
    bar.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
    let enabled = args["enabled"] as? Bool ?? false
    let actions = args["actions"] as? [[String: String]] ?? []
    let photoViewer = args["photoViewer"] as? Bool ?? false
    let photoSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular, scale: .medium)
    let rebuildActions = actionItems.count != actions.count || photoControls != photoViewer
    actionLabels = actions.map { $0["label"] ?? "" }
    photoControls = photoViewer
    if rebuildActions {
      actionItems = actions.indices.map { index in
        let callback = UIAction { [weak self] _ in
          guard let self = self, self.actionLabels.indices.contains(index) else { return }
          self.channel.invokeMethod("action", arguments: self.actionLabels[index])
        }
        let item: UIBarButtonItem
        if photoViewer {
          // Retain the button and its target constraints across state updates.
          let button = UIButton(type: .system, primaryAction: callback)
          button.widthAnchor.constraint(equalToConstant: 48).isActive = true
          button.heightAnchor.constraint(equalToConstant: 44).isActive = true
          item = UIBarButtonItem(customView: button)
        } else { item = UIBarButtonItem(title: nil, image: nil, primaryAction: callback) }
        item.width = 48
        return item
      }
    }
    for (index, action) in actions.enumerated() {
      let item = actionItems[index]
      let label = action["label"] ?? ""
      let image = UIImage(systemName: action["symbol"] ?? "",
        withConfiguration: photoViewer ? photoSymbolConfiguration : nil)
      if let button = item.customView as? UIButton {
        // System toolbar items may report a 38-point target on iOS 26. Give
        // the native button explicit bounds while retaining toolbar-owned glass.
        var configuration = UIButton.Configuration.plain()
        configuration.image = image
        configuration.baseForegroundColor = .white
        configuration.contentInsets = .zero
        button.configuration = configuration
        button.accessibilityLabel = label
        button.isEnabled = enabled
        if action["selected"] == "true" { button.accessibilityTraits.insert(.selected) }
        else { button.accessibilityTraits.remove(.selected) }
      } else {
        item.image = image
        item.accessibilityLabel = label
        item.isEnabled = enabled
      }
    }
    let selectAll = args["selectAll"] as? Bool ?? false
    let clear = args["clear"] as? Bool ?? false
    // Updating a star, selection or appearance must not replace focused items.
    let rebuildLayout = previous == nil || rebuildActions ||
      (previous?["selectAll"] as? Bool ?? false) != selectAll ||
      (previous?["clear"] as? Bool ?? false) != clear
    guard rebuildLayout else { return }
    var items = actionItems
    if photoViewer {
      // Flexible spaces form three system-glass groups with identical symbols.
      items.insert(UIBarButtonItem(systemItem: .flexibleSpace), at: 1)
      if items.count > 4 { items.insert(UIBarButtonItem(systemItem: .flexibleSpace), at: 4) }
    }
    if selectAll || clear {
      items.append(UIBarButtonItem(systemItem: .flexibleSpace))
      var menu: [UIAction] = []
      if selectAll {
        menu.append(UIAction(title: "Select All", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
          self?.channel.invokeMethod("action", arguments: "Select All")
        })
      }
      if clear {
        menu.append(UIAction(title: "Deselect All", image: UIImage(systemName: "circle")) { [weak self] _ in
          self?.channel.invokeMethod("action", arguments: "Deselect All")
        })
      }
      let more = UIBarButtonItem(title: nil, image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: menu))
      more.accessibilityLabel = "Selection options"
      more.width = 44
      items.append(more)
    }
    bar.setItems(items, animated: false)
  }
  deinit { channel.setMethodCallHandler(nil) }
}
