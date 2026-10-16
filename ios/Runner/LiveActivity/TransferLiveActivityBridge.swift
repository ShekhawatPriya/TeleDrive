import ActivityKit
import Flutter
import UIKit

/// MethodChannel `teledrive/live-activity`: Dart owns *what* the upload
/// Live Activity says; this bridge owns the ActivityKit lifecycle, ordering,
/// and what happens when iOS suspends TeleDrive mid-transfer.
@MainActor
final class TransferLiveActivityBridge: NSObject {
  private let channel: FlutterMethodChannel
  private var controller: AnyObject?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "teledrive/live-activity", binaryMessenger: messenger)
    super.init()
    if #available(iOS 16.2, *) { controller = TransferActivityController() }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  /// Tapping the activity opens `teledrive://transfers`.
  func openTransfers() {
    channel.invokeMethod("openTransfers", arguments: nil)
  }

  static func handles(_ url: URL) -> Bool {
    url.scheme == "teledrive" && url.host == "transfers"
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *), let controller = controller as? TransferActivityController else {
      if call.method == "status" { result(["supported": false, "enabled": false]) }
      else { result(false) }
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    let sessionId = args["sessionId"] as? String ?? ""
    let state = (args["state"] as? [String: Any]).map(TransferActivityState.init(map:))
    switch call.method {
    case "status":
      result(["supported": true, "enabled": ActivityAuthorizationInfo().areActivitiesEnabled])
    case "start":
      guard let state else { result(false); return }
      controller.start(sessionId: sessionId, state: state, result: result)
    case "update":
      guard let state else { result(false); return }
      controller.update(sessionId: sessionId, state: state, result: result)
    case "end":
      guard let state else { result(false); return }
      let alert = (args["alertTitle"] as? String).map {
        (title: $0, body: args["alertBody"] as? String ?? "")
      }
      controller.end(
        sessionId: sessionId, state: state, alert: alert,
        lingerSeconds: (args["lingerSeconds"] as? NSNumber)?.doubleValue ?? 0,
        dismissAfterSeconds: (args["dismissAfterSeconds"] as? NSNumber)?.doubleValue,
        result: result)
    case "endAll":
      controller.endAll(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

@available(iOS 16.2, *)
@MainActor
final class TransferActivityController {
  /// Running content older than this renders as paused. Dart re-sends at
  /// least every minute while TeleDrive is actually running.
  private static let staleInterval: TimeInterval = 150

  private var activity: Activity<TransferActivityAttributes>?
  /// Last state Dart reported, kept apart from the native paused overlay.
  private var reported: TransferActivityState?
  private var pausedForBackground = false
  private var tail: Task<Void, Never>?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  init() {
    // Upload sessions do not survive relaunch, so any activity still around
    // belongs to a previous process and would otherwise freeze on screen.
    enqueue {
      for orphan in Activity<TransferActivityAttributes>.activities {
        await orphan.end(nil, dismissalPolicy: .immediate)
      }
    }
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(didEnterBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    center.addObserver(
      self, selector: #selector(willEnterForeground),
      name: UIApplication.willEnterForegroundNotification, object: nil)
  }

  // MARK: Dart operations, applied strictly in order.

  func start(sessionId: String, state: TransferActivityState, result: @escaping FlutterResult) {
    enqueue { [self] in
      if let current = activity, current.attributes.sessionId == sessionId {
        // Removed by the person mid-session: respect that until a new one.
        if isLive(current) { await apply(state, to: current) } else { activity = nil }
        result(activity != nil)
        return
      }
      if let previous = activity {
        await previous.end(nil, dismissalPolicy: .immediate)
        activity = nil
      }
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { result(false); return }
      do {
        activity = try Activity.request(
          attributes: TransferActivityAttributes(sessionId: sessionId),
          content: content(state), pushType: nil)
        reported = state
        pausedForBackground = false
        result(true)
      } catch {
        // Typically: started from the background, or the system limit on
        // concurrent activities was reached. Uploads continue regardless.
        result(false)
      }
    }
  }

  func update(sessionId: String, state: TransferActivityState, result: @escaping FlutterResult) {
    enqueue { [self] in
      guard let current = activity, current.attributes.sessionId == sessionId, isLive(current) else {
        // Ended by the person (removed from the Lock Screen) or the system.
        activity = nil
        result(false)
        return
      }
      await apply(state, to: current)
      result(true)
    }
  }

  func end(
    sessionId: String, state: TransferActivityState, alert: (title: String, body: String)?,
    lingerSeconds: Double, dismissAfterSeconds: Double?, result: @escaping FlutterResult
  ) {
    enqueue { [self] in
      guard let current = activity, current.attributes.sessionId == sessionId else {
        result(false)
        return
      }
      activity = nil
      reported = state
      // Hold execution so the outcome reaches the island even if TeleDrive is
      // being backgrounded at this moment.
      beginBackgroundTask()
      result(true)
      let final = ActivityContent(state: state, staleDate: nil)
      if isLive(current) {
        if let alert {
          // Alerts expand the island (or show a banner without one) — only
          // sent when the matching upload alert setting is on.
          await current.update(
            final,
            alertConfiguration: AlertConfiguration(
              title: LocalizedStringResource(stringLiteral: alert.title),
              body: LocalizedStringResource(stringLiteral: alert.body),
              sound: .default))
        } else if lingerSeconds > 0 {
          await current.update(final)
        }
        // Ending removes the activity from the island at once; a short linger
        // lets "Done" register there before the Lock Screen summary remains.
        if lingerSeconds > 0 {
          try? await Task.sleep(nanoseconds: UInt64(lingerSeconds * 1_000_000_000))
        }
      }
      let policy: ActivityUIDismissalPolicy
      switch dismissAfterSeconds {
      case nil: policy = .default
      case let seconds? where seconds <= 0: policy = .immediate
      case let seconds?: policy = .after(Date().addingTimeInterval(seconds))
      }
      await current.end(final, dismissalPolicy: policy)
      if activity == nil { endBackgroundTask() }
    }
  }

  func endAll(result: @escaping FlutterResult) {
    enqueue { [self] in
      activity = nil
      reported = nil
      for running in Activity<TransferActivityAttributes>.activities {
        await running.end(nil, dismissalPolicy: .immediate)
      }
      endBackgroundTask()
      result(true)
    }
  }

  // MARK: Suspension

  /// Leaving the app mid-upload buys the usual background grace period, so
  /// transfers keep moving briefly; when iOS reclaims it, say "Paused"
  /// rather than leave a percentage that silently stopped.
  @objc private func didEnterBackground() {
    guard activity != nil, let reported, !reported.phase.isTerminal else { return }
    beginBackgroundTask()
  }

  @objc private func willEnterForeground() {
    endBackgroundTask()
    guard pausedForBackground else { return }
    pausedForBackground = false
    enqueue { [self] in
      if let current = activity, let reported, isLive(current) {
        await current.update(content(reported))
      }
    }
  }

  private func beginBackgroundTask() {
    guard backgroundTask == .invalid else { return }
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "TeleDrive transfers") {
      [weak self] in
      self?.backgroundTimeExpired()
    }
  }

  private func backgroundTimeExpired() {
    guard let current = activity, var paused = reported, !paused.phase.isTerminal else {
      endBackgroundTask()
      return
    }
    paused.phase = .paused
    pausedForBackground = true
    Task { @MainActor [weak self] in
      await current.update(ActivityContent(state: paused, staleDate: nil))
      self?.endBackgroundTask()
    }
    // The expiration handler must release the task promptly regardless.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      self?.endBackgroundTask()
    }
  }

  private func endBackgroundTask() {
    guard backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }

  // MARK: Helpers

  private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
    let previous = tail
    tail = Task { @MainActor in
      await previous?.value
      await operation()
    }
  }

  private func isLive(_ activity: Activity<TransferActivityAttributes>) -> Bool {
    activity.activityState == .active || activity.activityState == .stale
  }

  private func apply(_ state: TransferActivityState, to current: Activity<TransferActivityAttributes>) async {
    reported = state
    pausedForBackground = false
    await current.update(content(state))
  }

  private func content(_ state: TransferActivityState) -> ActivityContent<TransferActivityState> {
    let running = state.phase == .preparing || state.phase == .uploading
    return ActivityContent(
      state: state,
      staleDate: running ? Date().addingTimeInterval(Self.staleInterval) : nil)
  }
}
