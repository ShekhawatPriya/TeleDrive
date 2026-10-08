import Flutter
import UIKit

final class PhotosLibraryControlsFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    PhotosLibraryControlsView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

/// Keep the category selector, search, and emerging cancel surface in one UIKit
/// hierarchy. Flutter supplies state; UIKit owns materials, tracking and motion.
final class PhotosLibraryControlsView: NSObject, FlutterPlatformView, UITextFieldDelegate {
  private let root = PhotosControlsLayoutView()
  private let container = UIVisualEffectView(effect: nil)
  private let searchGlass = UIVisualEffectView(effect: nil)
  private let categoriesGlass = UIVisualEffectView(effect: nil)
  private let cancelGlass = UIVisualEffectView(effect: nil)
  private let search = UIButton(type: .system)
  private let cancel = UIButton(type: .system)
  private let field = UISearchTextField()
  private let segments = PhotosCategories(items: ["All media", "Photos", "Videos"])
  private let categoryScroll = PhotosCategoryScrollView()
  private let channel: FlutterMethodChannel
  private var expanded = false
  private var reducedMotion = false
  private var highContrast = false
  private var opaque = false
  private var scale: CGFloat = 1
  private var lastSize = CGSize.zero
  // Every toggle retargets the same spring from the views' current
  // presentation, so rapid taps never restart, reverse or skip the motion.
  private var animating = false
  private var transitionToken = 0
  private var disposed = false

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/photos-controls/\(id)", binaryMessenger: messenger)
    super.init()
    root.frame = frame
    root.backgroundColor = .clear
    root.addSubview(container)
    // Sibling effects in a single container are fused by UIKit, not by opacity
    // or a Flutter clipping mask. Cancel starts coincident with the search lens.
    for glass in [categoriesGlass, cancelGlass, searchGlass] {
      container.contentView.addSubview(glass)
      glass.layer.cornerCurve = .continuous
      glass.clipsToBounds = true
    }
    container.contentView.accessibilityElements = [searchGlass, categoriesGlass, cancelGlass]
    categoriesGlass.contentView.addSubview(categoryScroll)
    categoryScroll.addSubview(segments)
    categoryScroll.showsHorizontalScrollIndicator = true
    categoryScroll.showsVerticalScrollIndicator = false
    categoryScroll.contentInsetAdjustmentBehavior = .never
    categoryScroll.alwaysBounceHorizontal = false
    categoryScroll.accessibilityIdentifier = "photos-category-scroll"
    segments.accessibilityIdentifier = "photos-categories"
    segments.addTarget(self, action: #selector(selected), for: .valueChanged)
    searchGlass.contentView.addSubview(search)
    searchGlass.contentView.addSubview(field)
    cancelGlass.contentView.addSubview(cancel)
    search.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)), for: .normal)
    search.tintColor = .label
    search.accessibilityLabel = "Search photos and videos"
    search.accessibilityIdentifier = "photos-search-open"
    search.addTarget(self, action: #selector(openSearch), for: .touchUpInside)
    cancel.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
    cancel.tintColor = .label
    cancel.accessibilityLabel = "Cancel search"
    cancel.accessibilityIdentifier = "drive-search-cancel"
    cancel.addTarget(self, action: #selector(closeSearch), for: .touchUpInside)
    field.delegate = self
    field.placeholder = "Search photos and videos"
    field.accessibilityLabel = "Search photos and videos"
    field.accessibilityIdentifier = "drive-search-field"
    field.returnKeyType = .search
    field.enablesReturnKeyAutomatically = false
    field.autocorrectionType = .no
    field.autocapitalizationType = .none
    field.clearButtonMode = .whileEditing
    // Reuse the leading system button's glyph throughout the morph. A second
    // search-field glyph would crossfade at a different position and ghost.
    field.leftView = nil
    field.leftViewMode = .never
    field.borderStyle = .none
    field.backgroundColor = .clear
    field.addTarget(self, action: #selector(changed), for: .editingChanged)
    root.onLayout = { [weak self] in self?.resized() }
    root.onDetach = { [weak self] in self?.dismiss() }
    NotificationCenter.default.addObserver(self, selector: #selector(dismiss), name: UIApplication.willResignActiveNotification, object: nil)
    for name in [UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                 UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
                 UIAccessibility.reduceMotionStatusDidChangeNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged), name: name, object: nil)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, !self.disposed else { result(nil); return }
      switch call.method {
      case "update": self.update(call.arguments)
      case "dismiss": self.dismiss()
      case "dispose": self.dispose()
      default: result(FlutterMethodNotImplemented); return
      }
      result(nil)
    }
    update(arguments, initial: true)
  }

  func view() -> UIView { root }
  deinit { NotificationCenter.default.removeObserver(self); channel.setMethodCallHandler(nil) }

  private func dispose() {
    disposed = true
    settleAnimation()
    field.resignFirstResponder()
    NotificationCenter.default.removeObserver(self)
    channel.setMethodCallHandler(nil)
  }

  private func update(_ arguments: Any?, initial: Bool = false) {
    guard let args = arguments as? [String: Any] else { return }
    let newScale = CGFloat(args["textScale"] as? Double ?? 1)
    let newContrast = args["highContrast"] as? Bool ?? false
    let newMotion = args["reduceMotion"] as? Bool ?? false
    let newStyle: UIUserInterfaceStyle = (args["dark"] as? Bool ?? false) ? .dark : .light
    let appearanceChanged = initial || newScale != scale || newContrast != highContrast ||
      newMotion != reducedMotion || newStyle != root.overrideUserInterfaceStyle
    scale = newScale
    highContrast = newContrast
    reducedMotion = newMotion
    root.overrideUserInterfaceStyle = newStyle
    let text = args["text"] as? String ?? ""
    if field.text != text && field.markedTextRange == nil { field.text = text }
    let selection = min(2, max(0, args["selected"] as? Int ?? 0))
    if segments.selectedSegmentIndex != selection {
      segments.selectedSegmentIndex = selection
      revealSelection(animated: false)
    }
    if initial { expanded = args["searching"] as? Bool ?? !text.isEmpty }
    if appearanceChanged {
      settleAnimation()
      field.font = .systemFont(ofSize: 17 * scale)
      segments.font = UIFont.systemFont(ofSize: 15 * scale, weight: .medium)
      segments.reduceMotion = reducedMotion
      segments.highContrast = highContrast
      configureMaterials()
      layoutSurfaces(searching: expanded)
      updateOwnership()
    }
  }

  @objc private func accessibilityChanged() {
    settleAnimation()
    configureMaterials()
    layoutSurfaces(searching: expanded)
    updateOwnership()
  }

  private func configureMaterials() {
    opaque = highContrast || UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled
    if #available(iOS 26.0, *), !opaque {
      let effect = UIGlassContainerEffect()
      effect.spacing = 8
      container.effect = effect
      for glass in [searchGlass, cancelGlass] { glass.effect = material() }
      // The category control is a system UISegmentedControl, which renders its
      // own Liquid Glass track and selection lens; this view only clips it.
      categoriesGlass.effect = nil
      for glass in [searchGlass, cancelGlass, categoriesGlass] { glass.backgroundColor = .clear }
    } else {
      container.effect = nil
      for glass in [searchGlass, cancelGlass, categoriesGlass] {
        glass.effect = nil
        glass.backgroundColor = .secondarySystemBackground
      }
    }
    for glass in [searchGlass, cancelGlass, categoriesGlass] {
      glass.layer.borderWidth = highContrast || UIAccessibility.isDarkerSystemColorsEnabled ? 1 : 0
      glass.layer.borderColor = UIColor.label.resolvedColor(with: root.traitCollection).cgColor
    }
  }

  private func material() -> UIVisualEffect? {
    if #available(iOS 26.0, *), !opaque {
      let effect = UIGlassEffect(style: .regular)
      effect.isInteractive = true
      return effect
    }
    return nil
  }

  private func resized() {
    guard !disposed, root.bounds.size != lastSize else { return }
    lastSize = root.bounds.size
    settleAnimation()
    layoutSurfaces(searching: expanded)
    updateOwnership()
    revealSelection(animated: false)
  }

  private func layoutSurfaces(searching: Bool) {
    let bounds = root.bounds
    guard bounds.width > 0, bounds.height > 0 else { return }
    let side = bounds.height
    let gap: CGFloat = 12
    let categoryFrame = CGRect(x: side + gap, y: 0, width: max(44, bounds.width - side - gap), height: side)
    container.frame = bounds
    searchGlass.frame = CGRect(x: 0, y: 0, width: searching ? max(side, bounds.width - side - gap) : side, height: side)
    cancelGlass.frame = CGRect(x: searching ? bounds.width - side : 0, y: 0, width: side, height: side)
    categoriesGlass.frame = searching ? CGRect(x: bounds.width - side, y: 0, width: side, height: side) : categoryFrame
    for glass in [searchGlass, categoriesGlass, cancelGlass] { glass.layer.cornerRadius = side / 2 }
    search.frame = CGRect(x: 0, y: 0, width: side, height: side)
    field.frame = CGRect(x: side, y: 4, width: max(0, searchGlass.bounds.width - side - 12), height: max(0, side - 8))
    cancel.frame = cancelGlass.bounds
    categoryScroll.frame = CGRect(origin: .zero, size: categoryFrame.size)
    let font = UIFont.systemFont(ofSize: 15 * scale, weight: .medium)
    let titles = ["All media", "Photos", "Videos"]
    let widths = titles.map { max(44, ($0 as NSString).size(withAttributes: [.font: font]).width + 16) }
    // Horizontal UIKit scrolling preserves full Dynamic Type labels and targets
    // when the three segments cannot fit a narrow accessibility-size row.
    let width = max(categoryFrame.width, widths.reduce(0, +))
    let extra = max(0, width - widths.reduce(0, +)) / 3
    for (index, value) in widths.enumerated() { segments.setWidth(value + extra, forSegmentAt: index) }
    let scrolling = width > categoryFrame.width + 0.5
    let host = scrolling ? categoryScroll : categoriesGlass.contentView
    if segments.superview !== host { host.addSubview(segments) }
    categoryScroll.isHidden = !scrolling
    segments.frame = CGRect(x: 0, y: 0, width: width, height: side)
    segments.alpha = searching ? 0 : 1
    categoryScroll.contentSize = segments.bounds.size
    search.alpha = 1
    field.alpha = searching ? 1 : 0
    cancel.alpha = searching ? 1 : 0
    categoryScroll.alpha = searching ? 0 : 1
    categoriesGlass.alpha = opaque && searching ? 0 : 1
  }

  private func updateOwnership() {
    container.contentView.accessibilityElements = expanded
      ? [searchGlass, cancelGlass] : [searchGlass, categoriesGlass]
    searchGlass.contentView.accessibilityElements = expanded ? [field] : [search]
    cancelGlass.contentView.accessibilityElements = expanded ? [cancel] : []
    search.isHidden = false
    field.isHidden = !expanded && !animating
    categoriesGlass.isHidden = expanded && !animating
    // The same glyph also restores keyboard focus when the field is expanded.
    search.isUserInteractionEnabled = true
    search.isAccessibilityElement = !expanded
    search.accessibilityElementsHidden = expanded
    field.isUserInteractionEnabled = expanded
    field.isAccessibilityElement = expanded
    field.accessibilityElementsHidden = !expanded
    cancel.isUserInteractionEnabled = expanded
    cancel.isAccessibilityElement = expanded
    cancel.accessibilityElementsHidden = !expanded
    categoriesGlass.isUserInteractionEnabled = !expanded
    categoriesGlass.accessibilityElementsHidden = expanded
    segments.setAccessibilityActive(!expanded)
    cancelGlass.isHidden = !expanded && !animating
  }

  private func transition(to searching: Bool) {
    guard expanded != searching else { return }
    expanded = searching
    channel.invokeMethod("searching", arguments: searching)
    if reducedMotion || UIAccessibility.isReduceMotionEnabled {
      settleAnimation()
      UIView.performWithoutAnimation { self.layoutSurfaces(searching: searching) }
      updateOwnership()
      return
    }
    transitionToken += 1
    let token = transitionToken
    animating = true
    updateOwnership()
    // The categories leave quickly as the field takes their row and return
    // once the pill has room, instead of riding the spring across the cancel
    // button. A later animation on the same property replaces this one.
    let fade = { self.segments.alpha = searching ? 0 : 1; self.categoryScroll.alpha = searching ? 0 : 1 }
    defer {
      UIView.animate(
        withDuration: searching ? 0.14 : 0.26, delay: searching ? 0 : 0.12,
        options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut], animations: fade)
    }
    // beginFromCurrentState retargets from what is on screen and carries the
    // spring's velocity into the new direction, so an interrupted open flows
    // straight back into a close rather than snapping to either end.
    UIView.animate(
      withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0,
      options: [.beginFromCurrentState, .allowUserInteraction, .allowAnimatedContent]
    ) {
      self.layoutSurfaces(searching: searching)
    } completion: { [weak self] _ in
      guard let self = self, !self.disposed, token == self.transitionToken else { return }
      self.animating = false
      self.updateOwnership()
    }
  }

  private func settleAnimation() {
    transitionToken += 1
    animating = false
    for view in [searchGlass, categoriesGlass, cancelGlass, search, field, cancel, segments, categoryScroll] as [UIView] {
      view.layer.removeAllAnimations()
    }
  }

  private func revealSelection(animated: Bool) {
    guard segments.selectedSegmentIndex >= 0 else { return }
    let index = segments.selectedSegmentIndex
    let x = (0..<index).reduce(CGFloat.zero) { $0 + segments.widthForSegment(at: $1) }
    categoryScroll.scrollRectToVisible(CGRect(x: x, y: 0, width: segments.widthForSegment(at: index), height: segments.bounds.height), animated: animated)
  }

  @objc private func selected() {
    revealSelection(animated: !reducedMotion && !UIAccessibility.isReduceMotionEnabled)
    channel.invokeMethod("selected", arguments: segments.selectedSegmentIndex)
  }
  @objc private func openSearch() {
    transition(to: true)
    field.becomeFirstResponder()
  }
  @objc private func closeSearch() {
    field.text = ""
    field.resignFirstResponder()
    channel.invokeMethod("cancelled", arguments: nil)
    transition(to: false)
  }
  @objc private func changed() { channel.invokeMethod("changed", arguments: field.text ?? "") }
  @objc private func dismiss() { field.resignFirstResponder() }
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    field.resignFirstResponder()
    channel.invokeMethod("submitted", arguments: nil)
    return false
  }
}

private final class PhotosControlsLayoutView: UIView {
  var onLayout: (() -> Void)?
  var onDetach: (() -> Void)?
  override func layoutSubviews() { super.layoutSubviews(); onLayout?() }
  override func didMoveToWindow() { super.didMoveToWindow(); if window == nil { onDetach?() } }
}

private final class PhotosCategoryScrollView: UIScrollView {
  override func touchesShouldCancel(in view: UIView) -> Bool { true }
}

/// The system segmented control: on iOS 26 UIKit draws its Liquid Glass track
/// and selection lens and owns touch tracking, dragging and the selection
/// spring. Only text attributes and per-segment widths are configured.
private final class PhotosCategories: UISegmentedControl {
  var reduceMotion = false
  var highContrast = false
  var font = UIFont.systemFont(ofSize: 15, weight: .medium) {
    didSet { applyFont() }
  }

  init(items: [String]) {
    super.init(items: items)
    selectedSegmentIndex = 0
    applyFont()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func applyFont() {
    setTitleTextAttributes([.font: font, .foregroundColor: UIColor.label], for: .normal)
    setTitleTextAttributes([
      .font: UIFont.systemFont(ofSize: font.pointSize, weight: .semibold),
      .foregroundColor: UIColor.label,
    ], for: .selected)
  }

  /// UIKit draws the track and selection lens; nothing to refresh.
  func refreshMaterial(opaque: Bool) {}

  func setAccessibilityActive(_ active: Bool) {
    accessibilityElementsHidden = !active
    isUserInteractionEnabled = active
  }
}
