import AVFoundation
import AVKit
import Flutter
import UIKit

final class PhotoVideoFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    PhotoVideoView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

private final class PhotoVideoContainer: UIView {
  var attached: (() -> Void)?
  override func didMoveToWindow() { super.didMoveToWindow(); if window != nil { attached?() } }
}

/// AVKit owns transport controls, accessibility and its full-screen presentation.
/// This container never subclasses AVPlayerViewController or inspects private
/// AVKit classes. Dart owns source resolution, authentication and file actions.
final class PhotoVideoView: NSObject, FlutterPlatformView, AVPlayerViewControllerDelegate, UIGestureRecognizerDelegate {
  private let host: PhotoVideoContainer
  private let controller = AVPlayerViewController()
  private let player: AVPlayer
  private let channel: FlutterMethodChannel
  private let session: String
  private var observations: [NSKeyValueObservation] = []
  private var notifications: [NSObjectProtocol] = []
  private var periodic: Any?
  private var active: Bool
  private var foreground = true
  private var userPaused: Bool
  private var internalChange = false
  private var disposed = false
  private var fullscreen = false
  private var ownsAudioSession = false
  private var pendingPosition: Double
  private var restoredPosition = false
  private var dragAxis: NSLayoutConstraint.Axis?
  private var previousPoint = CGPoint.zero

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    let args = arguments as? [String: Any] ?? [:]
    session = args["session"] as? String ?? ""
    active = args["active"] as? Bool ?? false
    userPaused = args["userPaused"] as? Bool ?? false
    pendingPosition = (args["positionMs"] as? NSNumber)?.doubleValue ?? 0
    let source = args["source"] as? String ?? ""
    let url = source.hasPrefix("/") ? URL(fileURLWithPath: source) : URL(string: source)
    player = url.map { AVPlayer(url: $0) } ?? AVPlayer()
    player.isMuted = args["muted"] as? Bool ?? true
    host = PhotoVideoContainer(frame: frame)
    channel = FlutterMethodChannel(name: "teledrive/photo-video/\(id)", binaryMessenger: messenger)
    super.init()
    controller.player = player
    controller.delegate = self
    controller.showsPlaybackControls = true
    controller.allowsPictureInPicturePlayback = false
    controller.entersFullScreenWhenPlaybackBegins = false
    controller.exitsFullScreenWhenPlaybackEnds = false
    controller.videoGravity = .resizeAspect
    controller.view.backgroundColor = .clear
    host.backgroundColor = .clear
    host.accessibilityIdentifier = "photo-native-player"
    host.attached = { [weak self] in self?.attach() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, !self.disposed else { result(nil); return }
      let data = call.arguments as? [String: Any] ?? [:]
      guard data["session"] as? String == self.session else { result(nil); return }
      switch call.method {
      case "active":
        self.active = data["value"] as? Bool ?? false
        self.applyPlayback()
      case "seek":
        let ms = (data["positionMs"] as? NSNumber)?.doubleValue ?? 0
        self.player.seek(to: CMTime(seconds: max(0, ms) / 1000, preferredTimescale: 600))
      case "mute": self.player.isMuted = data["value"] as? Bool ?? true
      case "pause": self.userPaused = true; self.applyPlayback()
      case "status": self.sendState()
      case "dispose": self.dispose()
      default: result(FlutterMethodNotImplemented); return
      }
      result(nil)
    }
    observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
      guard let self else { return }
      if self.active && self.foreground && !self.internalChange && self.restoredPosition {
        if self.player.timeControlStatus == .playing { self.userPaused = false }
        else if self.player.timeControlStatus == .paused { self.userPaused = true; self.releaseAudioSession() }
      }
      self.sendState()
    })
    observations.append(player.observe(\.isMuted, options: [.new]) { [weak self] _, _ in
      self?.configureAudio(); self?.sendState()
    })
    observations.append(controller.observe(\.isReadyForDisplay, options: [.new]) { [weak self] _, _ in
      self?.applyPlayback()
    })
    if let item = player.currentItem {
      observations.append(item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
        guard let self else { return }
        if item.status == .readyToPlay && !self.restoredPosition {
          self.restoredPosition = true
          if self.pendingPosition > 0 {
            self.player.seek(to: CMTime(seconds: self.pendingPosition / 1000, preferredTimescale: 600)) { [weak self] _ in self?.applyPlayback() }
          } else { self.applyPlayback() }
        }
        self.sendState()
      })
      notifications.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
        self?.userPaused = true; self?.sendState()
      })
    }
    notifications.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.foreground = false; self?.applyPlayback()
    })
    notifications.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.foreground = true; self?.applyPlayback()
    })
    notifications.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
      guard let self, let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
      if raw == AVAudioSession.InterruptionType.began.rawValue {
        self.foreground = false
      } else {
        self.foreground = UIApplication.shared.applicationState == .active
        let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        if !AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { self.userPaused = true }
      }
      self.applyPlayback()
    })
    notifications.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
      if (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
        self?.userPaused = true; self?.applyPlayback()
      }
    })
    periodic = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] _ in self?.sendState() }
    let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
    pan.maximumNumberOfTouches = 1
    pan.cancelsTouchesInView = false
    pan.delegate = self
    host.addGestureRecognizer(pan)
    let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
    tap.cancelsTouchesInView = false
    tap.delegate = self
    host.addGestureRecognizer(tap)
  }

  func view() -> UIView { host }
  private func attach() {
    guard controller.parent == nil, !disposed else { return }
    var responder: UIResponder? = host.next
    while responder != nil && !(responder is UIViewController) { responder = responder?.next }
    guard let parent = responder as? UIViewController else { return }
    parent.addChild(controller)
    controller.view.frame = host.bounds
    controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    host.addSubview(controller.view)
    controller.didMove(toParent: parent)
    applyPlayback()
  }
  private func releaseAudioSession() {
    guard ownsAudioSession else { return }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    ownsAudioSession = false
  }
  private func configureAudio() {
    guard active && foreground && !userPaused else { return }
    do {
      if player.isMuted {
        // A muted preview must not interrupt music from another app.
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
      } else {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      }
      try AVAudioSession.sharedInstance().setActive(true)
      ownsAudioSession = true
    } catch { /* Playback controls remain usable if another session owns audio. */ }
  }
  private func applyPlayback() {
    guard !disposed else { return }
    internalChange = true
    if active && foreground && !userPaused && restoredPosition {
      configureAudio(); player.play()
    } else { player.pause(); releaseAudioSession() }
    internalChange = false
    sendState()
  }
  private func send(_ method: String, _ values: [String: Any]) {
    guard !disposed else { return }
    channel.invokeMethod(method, arguments: values.merging(["session": session]) { _, new in new })
  }
  private func sendState() {
    guard !disposed else { return }
    let item = player.currentItem
    let seconds = player.currentTime().seconds
    let duration = item?.duration.seconds ?? 0
    let size = item?.presentationSize ?? .zero
    var data: [String: Any] = ["ready": controller.isReadyForDisplay,
      "buffering": player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
      "muted": player.isMuted, "userPaused": userPaused,
      "positionMs": seconds.isFinite ? Int(max(0, seconds) * 1000) : 0,
      "durationMs": duration.isFinite ? Int(max(0, duration) * 1000) : 0,
      "width": size.width, "height": size.height]
    if item?.status == .failed { data["error"] = "Could not play this video." }
    send("state", data)
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    guard !fullscreen else { return false }
    // Controls are authoritative. Reserve the transport and upper control
    // regions as well as UIControl ancestors, without private-view matching.
    let point = touch.location(in: host)
    guard point.y > 88 && point.y < host.bounds.height - 144 else {
      return false
    }
    var view = touch.view
    while let current = view, current !== host {
      if current is UIControl { return false }
      view = current.superview
    }
    return true
  }
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard !fullscreen else { return false }
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
    let velocity = pan.velocity(in: host)
    return max(abs(velocity.x), abs(velocity.y)) > 0
  }
  @objc private func tapped() { send("tap", [:]) }
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UITapGestureRecognizer
  }
  @objc private func panned(_ pan: UIPanGestureRecognizer) {
    let point = pan.location(in: host.window)
    let velocity = pan.velocity(in: host)
    if pan.state == .began {
      dragAxis = abs(velocity.y) > abs(velocity.x) ? .vertical : .horizontal
      previousPoint = point
    }
    let axis = dragAxis == .horizontal ? "horizontal" : "vertical"
    switch pan.state {
    case .began:
      send("drag", ["phase": "start", "axis": axis, "x": point.x, "y": point.y])
    case .changed:
      send("drag", ["phase": "update", "axis": axis, "x": point.x, "y": point.y, "dx": point.x - previousPoint.x, "dy": point.y - previousPoint.y])
      previousPoint = point
    case .ended:
      send("drag", ["phase": "end", "axis": axis, "x": point.x, "y": point.y, "dx": velocity.x, "dy": velocity.y])
      dragAxis = nil
    case .cancelled, .failed:
      send("drag", ["phase": "cancel", "axis": axis]); dragAxis = nil
    default: break
    }
  }
  func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    fullscreen = true; send("fullscreen", ["value": true])
    coordinator.animate(alongsideTransition: nil) { [weak self] context in
      if context.isCancelled { self?.fullscreen = false; self?.send("fullscreen", ["value": false]) }
    }
  }
  func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    coordinator.animate(alongsideTransition: nil) { [weak self] context in
      guard !context.isCancelled else { return }
      self?.fullscreen = false; self?.send("fullscreen", ["value": false]); self?.applyPlayback()
    }
  }
  private func dispose() {
    guard !disposed else { return }
    disposed = true
    player.pause()
    if let periodic { player.removeTimeObserver(periodic) }; periodic = nil
    observations.removeAll()
    notifications.forEach(NotificationCenter.default.removeObserver); notifications.removeAll()
    controller.willMove(toParent: nil)
    controller.view.removeFromSuperview()
    controller.removeFromParent()
    controller.player = nil
    player.replaceCurrentItem(with: nil)
    host.attached = nil
    channel.setMethodCallHandler(nil)
    releaseAudioSession()
  }
  deinit { dispose() }
}
