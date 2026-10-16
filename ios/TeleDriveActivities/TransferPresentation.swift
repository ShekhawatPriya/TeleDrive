import SwiftUI

/// Everything the presentations say, derived once from the content state so
/// compact, minimal, expanded, and Lock Screen layouts never disagree.
struct TransferPresentation {
  let state: TransferActivityState
  let phase: TransferActivityPhase

  init(state: TransferActivityState, isStale: Bool) {
    self.state = state
    // A stale running activity means TeleDrive stopped reporting, which on
    // iOS means it was suspended: say so instead of freezing a percentage.
    phase = isStale && !state.phase.isTerminal ? .paused : state.phase
  }

  var isRunning: Bool { phase == .preparing || phase == .uploading }
  var isSettled: Bool { phase.isTerminal }
  var needsAttention: Bool { phase == .partial || phase == .failed }
  var isBackup: Bool { state.source == .backup }
  var percent: Int { Int((state.progress * 100).rounded(.down)) }

  var tint: Color {
    switch phase {
    case .preparing, .uploading: return isBackup ? .indigo : .blue
    case .waitingForWifi, .paused, .cancelled: return .gray
    case .completed: return .green
    case .partial: return .orange
    case .failed: return .red
    }
  }

  /// Ring fill; terminal states read as a closed ring.
  var ringProgress: Double {
    switch phase {
    case .completed, .partial, .failed: return 1
    case .cancelled: return 0
    default: return state.progress
    }
  }

  var symbol: String {
    switch phase {
    case .preparing, .uploading: return "arrow.up"
    case .waitingForWifi: return "wifi"
    case .paused: return "pause.fill"
    case .completed: return "checkmark"
    case .partial: return "exclamationmark"
    case .failed, .cancelled: return "xmark"
    }
  }

  var title: String {
    switch phase {
    case .preparing: return isBackup ? "Preparing Backup" : "Preparing Upload"
    case .uploading: return isBackup ? "Backing Up Photos" : "Uploading"
    case .waitingForWifi: return "Waiting for Wi-Fi"
    case .paused: return isBackup ? "Backup Paused" : "Upload Paused"
    case .completed: return isBackup ? "Backup Complete" : "Upload Complete"
    case .partial: return isBackup ? "Backup Finished" : "Upload Finished"
    case .failed: return isBackup ? "Backup Failed" : "Upload Failed"
    case .cancelled: return "Upload Cancelled"
    }
  }

  var subtitle: String {
    let total = state.totalCount
    let done = state.completedCount
    switch phase {
    case .preparing, .uploading:
      return total == 1 ? byteProgress : "\(done) of \(total) \(noun(total))"
    case .waitingForWifi:
      let left = max(total - done - state.failedCount, 0)
      return "\(left) \(noun(left)) queued"
    case .paused:
      return "Open TeleDrive to continue"
    // Settled states keep the running "3 of 12 files" form, so the same
    // line reads as the final count once the session ends.
    case .completed, .partial, .failed, .cancelled:
      return "\(done) of \(total) \(noun(total))"
    }
  }

  // MARK: Settled outcome (expanded and Lock Screen)

  /// Fraction that actually made it, for the final bar.
  var outcomeProgress: Double {
    state.totalCount == 0 ? 0 : Double(state.completedCount) / Double(state.totalCount)
  }

  /// The large trailing figure that replaces the running percentage: total
  /// size saved on success, otherwise how many files need attention.
  var outcomeFigure: (value: String, unit: String) {
    switch phase {
    case .completed:
      guard state.totalBytes > 0 else {
        return ("\(state.totalCount)", noun(state.totalCount))
      }
      let text = bytes(state.totalBytes)
      guard let split = text.lastIndex(where: { $0.isWhitespace }) else { return (text, "") }
      return (String(text[..<split]), String(text[text.index(after: split)...]))
    case .cancelled:
      return ("\(state.completedCount)", "saved")
    default:
      return ("\(state.failedCount)", "failed")
    }
  }

  /// The bottom row's message, in the place the running file name occupies.
  var outcomeMessage: String {
    let failed = state.failedCount
    switch phase {
    case .completed:
      return isBackup ? "All items backed up to TeleDrive" : "All files saved to TeleDrive"
    case .partial:
      return "\(failed) \(noun(failed)) didn’t upload"
    case .failed:
      return "Nothing was uploaded"
    default:
      return "Upload stopped"
    }
  }

  var outcomeSymbol: String {
    switch phase {
    case .completed: return "checkmark.icloud.fill"
    case .partial: return "exclamationmark.triangle.fill"
    default: return "xmark.icloud.fill"
    }
  }

  /// Short trailing compact label: balanced in width with the leading ring.
  var compactLabel: String {
    switch phase {
    case .preparing, .uploading: return "\(percent)%"
    case .waitingForWifi: return "Wi-Fi"
    case .paused: return "Paused"
    case .completed: return "Done"
    case .partial: return "\(state.failedCount) failed"
    case .failed: return "Failed"
    case .cancelled: return "Stopped"
    }
  }

  var byteProgress: String {
    guard state.totalBytes > 0 else { return "" }
    return "\(bytes(state.completedBytes)) of \(bytes(state.totalBytes))"
  }

  var kindSymbol: String {
    switch state.currentKind {
    case .image: return "photo"
    case .video: return "video"
    case .audio: return "waveform"
    case .document: return "doc.text"
    case .archive: return "archivebox"
    case .other: return "doc"
    }
  }

  var accessibilitySummary: String {
    switch phase {
    case .preparing, .uploading: return "\(title), \(percent) percent, \(subtitle)"
    default: return "\(title), \(subtitle)"
    }
  }

  private func noun(_ count: Int) -> String {
    if isBackup { return count == 1 ? "item" : "items" }
    return count == 1 ? "file" : "files"
  }

  private func bytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
  }
}
