import ActivityKit
import Foundation

/// Shared by Runner (which starts and updates the activity) and the
/// TeleDriveActivities widget extension (which renders it). Keep the encoded
/// form small: ActivityKit rejects attributes plus state above 4 KB.
@available(iOS 16.1, *)
struct TransferActivityAttributes: ActivityAttributes {
  typealias ContentState = TransferActivityState

  /// The upload session this activity tracks; one activity per session.
  let sessionId: String
}

enum TransferActivityPhase: String, Codable, Hashable {
  case preparing
  case uploading
  case waitingForWifi
  /// Set natively when iOS suspends TeleDrive before the queue finishes.
  case paused
  case completed
  case partial
  case failed
  case cancelled

  var isTerminal: Bool {
    switch self {
    case .completed, .partial, .failed, .cancelled: return true
    default: return false
    }
  }
}

enum TransferActivitySource: String, Codable, Hashable {
  case uploads
  case backup
}

enum TransferActivityFileKind: String, Codable, Hashable {
  case image, video, audio, document, archive, other
}

struct TransferActivityState: Codable, Hashable {
  var phase: TransferActivityPhase
  var source: TransferActivitySource
  var totalCount: Int
  var completedCount: Int
  var failedCount: Int
  /// Whole-session progress in 0...1, matching the in-app upload panel.
  var progress: Double
  var completedBytes: Int64
  var totalBytes: Int64
  /// File currently transferring; rendered as privacy-sensitive.
  var currentName: String?
  var currentKind: TransferActivityFileKind

  /// Tolerates partial maps so a newer Dart payload never crashes Runner.
  init(map: [String: Any]) {
    phase = TransferActivityPhase(rawValue: map["phase"] as? String ?? "") ?? .uploading
    source = TransferActivitySource(rawValue: map["source"] as? String ?? "") ?? .uploads
    totalCount = max(0, (map["totalCount"] as? NSNumber)?.intValue ?? 0)
    completedCount = max(0, (map["completedCount"] as? NSNumber)?.intValue ?? 0)
    failedCount = max(0, (map["failedCount"] as? NSNumber)?.intValue ?? 0)
    progress = min(1, max(0, (map["progress"] as? NSNumber)?.doubleValue ?? 0))
    completedBytes = max(0, (map["completedBytes"] as? NSNumber)?.int64Value ?? 0)
    totalBytes = max(0, (map["totalBytes"] as? NSNumber)?.int64Value ?? 0)
    let name = (map["currentName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    // Long names only truncate on screen; cap them to stay inside 4 KB.
    currentName = name.flatMap { $0.isEmpty ? nil : String($0.prefix(120)) }
    currentKind = TransferActivityFileKind(rawValue: map["currentKind"] as? String ?? "") ?? .other
  }
}
