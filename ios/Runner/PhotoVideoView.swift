import AVFoundation
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

/// A bare video surface. As in Photos, the viewer's own chrome owns the
/// transport (play, scrubber, mute), so there are no AVKit controls, no second
/// tap-to-show layer and no system full-screen presentation.
private final class PhotoVideoSurface: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// Dart owns source resolution, authentication, file actions and the
/// transport controls. This view plays, reports state, and forwards taps and
/// unclaimed pans to the shared pager/stage.
final class PhotoVideoView: NSObject, FlutterPlatformView, UIGestureRecognizerDelegate {
  private let host: PhotoVideoSurface
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
  private var ownsAudioSession = false
  private var pendingPosition: Double
  private var restoredPosition = false
  private var filled = false
  private var seeking = false
  private var pendingSeek: (time: CMTime, exact: Bool)?
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
    host = PhotoVideoSurface(frame: frame)
    channel = FlutterMethodChannel(name: "teledrive/photo-video/\(id)", binaryMessenger: messenger)
    super.init()
    host.backgroundColor = .clear
    host.playerLayer.player = player
    host.playerLayer.videoGravity = .resizeAspect
    host.accessibilityIdentifier = "photo-native-player"
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, !self.disposed else { result(nil); return }
      let data = call.arguments as? [String: Any] ?? [:]
      guard data["session"] as? String == self.session else { result(nil); return }
      switch call.method {
      case "active":
        self.active = data["value"] as? Bool ?? false
        self.applyPlayback()
      case "play":
        self.userPaused = false
        if self.atEnd { self.seek(to: .zero, exact: true) }
        self.applyPlayback()
      case "pause": self.userPaused = true; self.applyPlayback()
      case "seek":
        let ms = (data["positionMs"] as? NSNumber)?.doubleValue ?? 0
        self.seek(to: CMTime(seconds: max(0, ms) / 1000, preferredTimescale: 600),
          exact: data["exact"] as? Bool ?? true)
      case "mute": self.player.isMuted = data["value"] as? Bool ?? true
      case "fill": self.setFilled(data["value"] as? Bool ?? false)
      case "status": self.sendState()
      case "dispose": self.dispose()
      default: result(FlutterMethodNotImplemented); return
      }
      result(nil)
    }
    observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
      guard let self else { return }
      if self.active && self.foreground && !self.internalChange && self.restoredPosition && !self.seeking {
        if self.player.timeControlStatus == .playing { self.userPaused = false }
        else if self.player.timeControlStatus == .paused && !self.atEnd { self.userPaused = true; self.releaseAudioSession() }
      }
      self.sendState()
    })
    observations.append(player.observe(\.isMuted, options: [.new]) { [weak self] _, _ in
      self?.configureAudio(); self?.sendState()
    })
    observations.append(host.playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] _, _ in
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
      // Videos loop, as with Photos' Loop Videos setting. An explicit pause
      // still holds, and an inactive page never restarts.
      notifications.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
        guard let self, !self.disposed else { return }
        self.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
          self?.applyPlayback()
        }
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
    // Ten updates a second keep the scrubber moving smoothly.
    periodic = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] _ in self?.sendState() }
    let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
    pan.maximumNumberOfTouches = 1
    pan.delegate = self
    host.addGestureRecognizer(pan)
    // Double-tap switches between fit and fill; the single tap that shows or
    // hides the viewer's chrome waits for it, as in Photos.
    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
    doubleTap.numberOfTapsRequired = 2
    doubleTap.delegate = self
    host.addGestureRecognizer(doubleTap)
    let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
    tap.require(toFail: doubleTap)
    tap.delegate = self
    host.addGestureRecognizer(tap)
  }

  func view() -> UIView { host }
  private var atEnd: Bool {
    guard let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 else { return false }
    return player.currentTime().seconds >= duration - 0.05
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
    } catch { /* Playback stays usable if another session owns audio. */ }
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
  /// Scrubbing issues many targets; only the newest waits while one seek runs.
  private func seek(to time: CMTime, exact: Bool) {
    pendingSeek = (time, exact)
    guard !seeking else { return }
    runPendingSeek()
  }
  private func runPendingSeek() {
    guard let next = pendingSeek, !disposed else { seeking = false; return }
    pendingSeek = nil
    seeking = true
    let tolerance = next.exact ? CMTime.zero : CMTime(seconds: 0.2, preferredTimescale: 600)
    player.seek(to: next.time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
      guard let self else { return }
      if self.pendingSeek == nil { self.seeking = false; self.sendState() }
      else { self.runPendingSeek() }
    }
  }
  private func setFilled(_ value: Bool) {
    guard value != filled else { return }
    filled = value
    CATransaction.begin()
    CATransaction.setAnimationDuration(UIAccessibility.isReduceMotionEnabled ? 0 : 0.25)
    host.playerLayer.videoGravity = value ? .resizeAspectFill : .resizeAspect
    CATransaction.commit()
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
    var data: [String: Any] = ["ready": host.playerLayer.isReadyForDisplay,
      "buffering": player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
      "playing": player.timeControlStatus != .paused,
      "muted": player.isMuted, "userPaused": userPaused, "filled": filled,
      "positionMs": seconds.isFinite ? Int(max(0, seconds) * 1000) : 0,
      "durationMs": duration.isFinite ? Int(max(0, duration) * 1000) : 0,
      "width": size.width, "height": size.height]
    if item?.status == .failed { data["error"] = "Could not play this video." }
    send("state", data)
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    !disposed
  }
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
    let velocity = pan.velocity(in: host)
    return max(abs(velocity.x), abs(velocity.y)) > 0
  }
  @objc private func tapped() { send("tap", [:]) }
  @objc private func doubleTapped() { setFilled(!filled) }
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
  private func dispose() {
    guard !disposed else { return }
    disposed = true
    player.pause()
    if let periodic { player.removeTimeObserver(periodic) }; periodic = nil
    observations.removeAll()
    notifications.forEach(NotificationCenter.default.removeObserver); notifications.removeAll()
    host.playerLayer.player = nil
    player.replaceCurrentItem(with: nil)
    channel.setMethodCallHandler(nil)
    releaseAudioSession()
  }
  deinit { dispose() }
}
