import Flutter
import UIKit

final class NativeSearchFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeSearchView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

/// A single container lets UIKit merge and separate the two actual glass shapes.
/// UITextField owns its responder, keyboard Search action and accessibility.
final class NativeSearchView: NSObject, FlutterPlatformView, UITextFieldDelegate {
  private let root = SearchLayoutView()
  private let field = UISearchTextField()
  private let cancel = UIButton(type: .system)
  private let channel: FlutterMethodChannel
  private var container = UIVisualEffectView(effect: nil)
  private let fieldGlass = UIVisualEffectView(effect: nil)
  private let cancelGlass = UIVisualEffectView(effect: nil)
  private var active = false
  private var keepCancelVisible = false
  private var pendingFocus = false
  private var reduceMotion = false
  private var highContrast = false
  private var lastSize = CGSize.zero
  private var transitionGeneration = 0

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/search/\(id)", binaryMessenger: messenger)
    super.init()
    root.frame = frame
    root.backgroundColor = .clear
    root.addSubview(container)
    container.contentView.addSubview(cancelGlass)
    container.contentView.addSubview(fieldGlass)
    fieldGlass.contentView.addSubview(field)
    cancelGlass.contentView.addSubview(cancel)
    field.delegate = self
    field.returnKeyType = .search
    field.enablesReturnKeyAutomatically = false
    field.autocorrectionType = .no
    field.autocapitalizationType = .none
    field.borderStyle = .none
    field.backgroundColor = .clear
    field.clearButtonMode = .whileEditing
    field.tintColor = .teleAccent
    field.accessibilityIdentifier = "drive-search-field"
    field.addTarget(self, action: #selector(changed), for: .editingChanged)
    cancel.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
    cancel.tintColor = .label
    cancel.accessibilityLabel = "Cancel search"
    cancel.accessibilityIdentifier = "drive-search-cancel"
    cancel.addTarget(self, action: #selector(cancelled), for: .touchUpInside)
    root.onLayout = { [weak self] in
      guard let self = self else { return }
      if self.root.bounds.size != self.lastSize {
        self.lastSize = self.root.bounds.size
        self.layoutShapes()
      }
      if self.pendingFocus, self.root.window != nil, self.field.bounds.width > 0 {
        self.pendingFocus = false
        // Flutter attaches platform views before their first usable layout.
        // Start editing after that layout has reached UIKit's run loop.
        DispatchQueue.main.async { [weak self] in
          guard let self = self, self.root.window != nil else { return }
          self.field.becomeFirstResponder()
        }
      }
    }
    root.onDetach = { [weak self] in self?.field.resignFirstResponder() }
    root.onAttach = { [weak self] in self?.root.setNeedsLayout() }
    NotificationCenter.default.addObserver(self, selector: #selector(dismiss), name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      if call.method == "update" { self.update(call.arguments); result(nil) }
      else if call.method == "dismiss" { self.dismiss(); result(nil) }
      else { result(FlutterMethodNotImplemented) }
    }
    pendingFocus = (arguments as? [String: Any])?["autofocus"] as? Bool ?? false
    update(arguments)
    layoutShapes()
    cancelGlass.isHidden = !active
  }

  func view() -> UIView { root }
  deinit { NotificationCenter.default.removeObserver(self); channel.setMethodCallHandler(nil) }

  private func update(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    root.overrideUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
    let text = args["text"] as? String ?? ""
    // Do not replace marked IME text while composing.
    if field.text != text && field.markedTextRange == nil { field.text = text }
    field.placeholder = args["placeholder"] as? String
    field.accessibilityLabel = args["placeholder"] as? String
    field.font = UIFont.systemFont(ofSize: 17 * CGFloat(args["textScale"] as? Double ?? 1))
    reduceMotion = args["reduceMotion"] as? Bool ?? false
    highContrast = args["highContrast"] as? Bool ?? false
    configureMaterials()
    keepCancelVisible = args["keepCancelVisible"] as? Bool ?? false
    setActive(keepCancelVisible || (args["active"] as? Bool ?? false))
  }

  @objc private func appearanceChanged() { configureMaterials() }
  private func configureMaterials() {
    let opaque = highContrast || UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled
    if #available(iOS 26.0, *), !opaque {
      if container.effect == nil {
        let effect = UIGlassContainerEffect()
        // Resting 12-point gap exceeds the fusion threshold; during the
        // spring both shapes cross it continuously and merge into one pill.
        effect.spacing = 8
        container.effect = effect
        let inputEffect = UIGlassEffect(style: .regular)
        let buttonEffect = UIGlassEffect(style: .regular)
        buttonEffect.isInteractive = true
        fieldGlass.effect = inputEffect
        cancelGlass.effect = buttonEffect
      }
      fieldGlass.backgroundColor = .clear
      cancelGlass.backgroundColor = .clear
    } else {
      container.effect = nil
      fieldGlass.effect = nil
      cancelGlass.effect = nil
      fieldGlass.backgroundColor = .secondarySystemBackground
      cancelGlass.backgroundColor = .secondarySystemBackground
    }
  }

  private func layoutShapes() {
    let bounds = root.bounds
    container.frame = bounds
    let side = bounds.height
    let fieldWidth = max(side, bounds.width - (active ? side + 12 : 0))
    fieldGlass.frame = CGRect(x: 0, y: 0, width: fieldWidth, height: side)
    cancelGlass.frame = CGRect(x: bounds.width - side, y: 0, width: side, height: side)
    for glass in [fieldGlass, cancelGlass] {
      glass.layer.cornerRadius = side / 2
      glass.layer.cornerCurve = .continuous
      glass.clipsToBounds = true
    }
    field.frame = fieldGlass.bounds.insetBy(dx: 12, dy: 4)
    cancel.frame = cancelGlass.bounds
    // Fade the material too: an overlapping glass circle still changes the
    // merged silhouette even when its X is transparent.
    cancelGlass.alpha = active ? 1 : 0
    cancel.alpha = active ? 1 : 0
    cancelGlass.isUserInteractionEnabled = active
    cancelGlass.accessibilityElementsHidden = !active
  }

  private func setActive(_ value: Bool) {
    guard active != value else { return }
    active = value
    transitionGeneration += 1
    let generation = transitionGeneration
    cancelGlass.isHidden = false
    if reduceMotion || UIAccessibility.isReduceMotionEnabled {
      UIView.performWithoutAnimation { self.layoutShapes() }
      cancelGlass.isHidden = !active
    } else {
      UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.92,
        initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
          self.layoutShapes()
      } completion: { [weak self] _ in
        guard let self = self, self.transitionGeneration == generation else { return }
        self.cancelGlass.isHidden = !self.active
      }
    }
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
    setActive(true)
    channel.invokeMethod("began", arguments: nil)
  }
  func textFieldDidEndEditing(_ textField: UITextField) {
    if !keepCancelVisible && (field.text ?? "").isEmpty { setActive(false) }
    channel.invokeMethod("ended", arguments: nil)
  }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    field.resignFirstResponder()
    channel.invokeMethod("submitted", arguments: nil)
    return false
  }
  @objc private func changed() { channel.invokeMethod("changed", arguments: field.text ?? "") }
  @objc private func cancelled() {
    field.text = ""
    field.resignFirstResponder()
    setActive(false)
    channel.invokeMethod("cancelled", arguments: nil)
  }
  @objc private func dismiss() { field.resignFirstResponder() }
}

private final class SearchLayoutView: UIView {
  var onLayout: (() -> Void)?
  var onDetach: (() -> Void)?
  var onAttach: (() -> Void)?
  override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { onDetach?() } else { onAttach?() }
  }
}

/// Native source chooser, including an anchored iPad popover. The selected
/// system picker is presented only after this controller finishes dismissing.
final class UploadSourceChooser: NSObject, UIAdaptivePresentationControllerDelegate {
  private var pending: FlutterResult?
  func show(_ arguments: Any?, result: @escaping FlutterResult) {
    guard pending == nil else { result(FlutterError(code: "busy", message: "A picker is already open", details: nil)); return }
    guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows }).first(where: { $0.isKeyWindow }),
      var presenter = window.rootViewController else { result(nil); return }
    while let presented = presenter.presentedViewController { presenter = presented }
    presenter.view.endEditing(true)
    pending = result
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    if let args = arguments as? [String: Any], let dark = args["dark"] as? Bool {
      alert.overrideUserInterfaceStyle = dark ? .dark : .light
    }
    func add(_ title: String, _ value: String?, _ style: UIAlertAction.Style = .default) {
      alert.addAction(UIAlertAction(title: title, style: style) { [weak self, weak alert] _ in
        guard let self = self else { return }
        if let transition = alert?.transitionCoordinator {
          transition.animate(alongsideTransition: nil) { _ in self.finish(value) }
        } else {
          presenter.dismiss(animated: true) { self.finish(value) }
        }
      })
    }
    add("Upload from Photos", "photos")
    add("Upload from Files", "files")
    add("Cancel", nil, .cancel)
    if let popover = alert.popoverPresentationController {
      popover.sourceView = presenter.view
      // Flutter sends the actual Add control in root-view logical coordinates.
      // Convert to the presenting view rather than guessing a footer location.
      if let args = arguments as? [String: Any],
         let x = args["x"] as? Double, let y = args["y"] as? Double,
         let width = args["width"] as? Double, let height = args["height"] as? Double,
         x.isFinite, y.isFinite, width.isFinite, height.isFinite, width > 0, height > 0,
         let rootView = window.rootViewController?.view {
        popover.sourceRect = presenter.view.convert(
          CGRect(x: x, y: y, width: width, height: height), from: rootView)
        popover.permittedArrowDirections = [.up, .down, .left, .right]
      } else {
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
          y: presenter.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }
    }
    alert.presentationController?.delegate = self
    presenter.present(alert, animated: true) {
      alert.presentationController?.delegate = self
    }
  }
  private func finish(_ value: String?) { let callback = pending; pending = nil; callback?(value) }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { finish(nil) }
}
