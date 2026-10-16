import ActivityKit
import SwiftUI
import WidgetKit

/// Upload and photo-backup progress on the Lock Screen and in the Dynamic
/// Island. Layout follows the HIG: the compact ring and percentage keep their
/// relative placement when the island expands (touch and hold), content hugs
/// the TrueDepth camera, and the Lock Screen uses the standard 14 pt margin.
struct TransferLiveActivity: Widget {
  static let openURL = URL(string: "teledrive://transfers")!

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TransferActivityAttributes.self) { context in
      LockScreenTransferView(
        model: TransferPresentation(state: context.state, isStale: context.isStale))
        .widgetURL(Self.openURL)
    } dynamicIsland: { context in
      let model = TransferPresentation(state: context.state, isStale: context.isStale)
      return DynamicIsland {
        // One grid for every state: leading badge, title and count in the
        // center, a large figure trailing, bar and detail row below. A
        // settled session keeps each element where the running one was and
        // shows its final value there.
        DynamicIslandExpandedRegion(.leading) {
          Group {
            if model.isSettled {
              OutcomeBadge(model: model, diameter: 50)
            } else {
              TransferRing(model: model, diameter: 46, lineWidth: 4.5, symbolSize: 17)
            }
          }
          .padding(.leading, 2)
          .frame(maxHeight: .infinity, alignment: .center)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Group {
            if model.isSettled {
              OutcomeFigure(model: model, valueSize: 28, unitSize: 15, color: model.tint)
                .padding(.trailing, 4)
            } else {
              ExpandedTrailing(model: model)
            }
          }
          .frame(maxHeight: .infinity, alignment: .center)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 1) {
            Text(model.title)
              .font(.system(.headline, design: .rounded).weight(.semibold))
              .foregroundStyle(.white)
            Text(model.subtitle)
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.white.opacity(0.62))
              .monospacedDigit()
          }
          .lineLimit(1)
          .minimumScaleFactor(0.85)
          .padding(.top, 2)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if model.isSettled {
            SettledBottom(model: model)
          } else {
            ExpandedBottom(model: model)
          }
        }
      } compactLeading: {
        TransferRing(model: model, diameter: 22, lineWidth: 3, symbolSize: 9)
          .accessibilityLabel(model.accessibilitySummary)
      } compactTrailing: {
        CompactTrailing(model: model)
      } minimal: {
        TransferRing(model: model, diameter: 22, lineWidth: 3, symbolSize: 9)
          .accessibilityLabel(model.accessibilitySummary)
      }
      .keylineTint(model.tint)
      .widgetURL(Self.openURL)
    }
  }
}

// MARK: - Shared pieces

/// Progress ring with a phase glyph; the shared visual anchor of every
/// presentation so the activity is recognizable at a glance.
struct TransferRing: View {
  let model: TransferPresentation
  let diameter: CGFloat
  let lineWidth: CGFloat
  let symbolSize: CGFloat
  var trackOpacity: Double = 0.24

  var body: some View {
    ZStack {
      Circle()
        .stroke(model.tint.opacity(trackOpacity), lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: max(model.ringProgress, model.isRunning ? 0.02 : 0))
        .stroke(model.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Image(systemName: model.symbol)
        .font(.system(size: symbolSize, weight: .heavy, design: .rounded))
        .foregroundStyle(model.tint)
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
        .id(model.symbol)
    }
    .frame(width: diameter, height: diameter)
    .padding(lineWidth / 2)
  }
}

private struct CompactTrailing: View {
  let model: TransferPresentation

  var body: some View {
    if #available(iOS 27.0, *) {
      LimitedWidthAware(model: model)
    } else {
      CompactTrailingLabel(model: model)
    }
  }
}

/// iPhone in landscape, or several concurrent activities, shrink the island
/// to a 28 pt circle per side. The ring alone carries the meaning there, so
/// the trailing side stays empty and the system hides it.
@available(iOS 27.0, *)
private struct LimitedWidthAware: View {
  let model: TransferPresentation
  @Environment(\.isDynamicIslandLimitedInWidth) private var limited

  var body: some View {
    if limited {
      EmptyView()
    } else {
      CompactTrailingLabel(model: model)
    }
  }
}

private struct CompactTrailingLabel: View {
  let model: TransferPresentation

  var body: some View {
    Text(model.compactLabel)
      .font(.system(size: 15, weight: .semibold, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(model.tint)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .contentTransition(.numericText())
      .accessibilityLabel(model.accessibilitySummary)
  }
}

private struct ExpandedTrailing: View {
  let model: TransferPresentation

  var body: some View {
    Group {
      if model.isRunning {
        Text("\(model.percent)%")
          .font(.system(size: 28, weight: .semibold, design: .rounded))
          .contentTransition(.numericText())
      } else {
        Text(model.compactLabel)
          .font(.system(size: 17, weight: .semibold, design: .rounded))
      }
    }
    .monospacedDigit()
    .foregroundStyle(model.tint)
    .lineLimit(1)
    .minimumScaleFactor(0.6)
    .padding(.trailing, 4)
    .accessibilityHidden(true)
  }
}

/// Running, paused, or waiting: a full-width bar plus the file in flight.
private struct ExpandedBottom: View {
  let model: TransferPresentation

  var body: some View {
    VStack(spacing: 8) {
      if model.isRunning || model.phase == .paused || model.phase == .waitingForWifi {
        LinearTransferBar(progress: model.state.progress, tint: model.tint)
        HStack(spacing: 6) {
          if let name = model.state.currentName, model.isRunning {
            Image(systemName: model.kindSymbol)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white.opacity(0.62))
            Text(name)
              .font(.footnote.weight(.medium))
              .foregroundStyle(.white.opacity(0.86))
              .lineLimit(1)
              .truncationMode(.middle)
              .privacySensitive()
          } else {
            Text(model.phase == .paused ? model.subtitle : model.title)
              .font(.footnote.weight(.medium))
              .foregroundStyle(.white.opacity(0.62))
          }
          Spacer(minLength: 8)
          if model.state.totalCount > 1, !model.byteProgress.isEmpty {
            Text(model.byteProgress)
              .font(.footnote.weight(.medium))
              .monospacedDigit()
              .foregroundStyle(.white.opacity(0.62))
              .lineLimit(1)
              .layoutPriority(1)
          }
        }
      }
    }
    .padding(.horizontal, 6)
    .padding(.top, 4)
    .accessibilityElement(children: .combine)
  }
}

/// Filled status disc for a settled session: a closed ring reads as
/// "still loading" at a glance, a solid glyph reads as an outcome.
struct OutcomeBadge: View {
  let model: TransferPresentation
  var diameter: CGFloat = 44
  var fillOpacity: Double = 0.2

  var body: some View {
    ZStack {
      Circle().fill(model.tint.opacity(fillOpacity))
      Image(systemName: model.symbol)
        .font(.system(size: diameter * 0.42, weight: .bold, design: .rounded))
        .foregroundStyle(model.tint)
    }
    .frame(width: diameter, height: diameter)
    .accessibilityHidden(true)
  }
}

/// Settled counterpart of `ExpandedBottom`: the bar shows what made it, and
/// the file row becomes the outcome, with "Review" where bytes were.
private struct SettledBottom: View {
  let model: TransferPresentation

  var body: some View {
    VStack(spacing: 8) {
      LinearTransferBar(progress: model.outcomeProgress, tint: model.tint)
      OutcomeRow(
        model: model, primary: .white.opacity(0.86), secondary: .white.opacity(0.62))
    }
    .padding(.horizontal, 6)
    .padding(.top, 4)
    .accessibilityElement(children: .combine)
  }
}

/// "All files saved to TeleDrive" or "1 file didn't upload … Review".
struct OutcomeRow: View {
  let model: TransferPresentation
  let primary: Color
  let secondary: Color

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: model.outcomeSymbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(model.tint)
      Text(model.outcomeMessage)
        .font(.footnote.weight(.medium))
        .foregroundStyle(primary)
        .lineLimit(1)
      Spacer(minLength: 8)
      if model.needsAttention {
        Text("Review")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(model.tint)
      }
    }
  }
}

/// Final value in the running percentage's place: "1.5 MB", "2 failed".
struct OutcomeFigure: View {
  let model: TransferPresentation
  let valueSize: CGFloat
  let unitSize: CGFloat
  let color: Color

  var body: some View {
    let figure = model.outcomeFigure
    HStack(alignment: .firstTextBaseline, spacing: 3) {
      Text(figure.value)
        .font(.system(size: valueSize, weight: .semibold, design: .rounded))
      if !figure.unit.isEmpty {
        Text(figure.unit)
          .font(.system(size: unitSize, weight: .semibold, design: .rounded))
      }
    }
    .monospacedDigit()
    .foregroundStyle(color)
    .lineLimit(1)
    .minimumScaleFactor(0.6)
    .accessibilityHidden(true)
  }
}

struct LinearTransferBar: View {
  let progress: Double
  let tint: Color
  var height: CGFloat = 6
  var trackColor: Color = .white.opacity(0.16)

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(trackColor)
        Capsule()
          .fill(tint)
          .frame(width: max(height, proxy.size.width * min(max(progress, 0), 1)))
      }
    }
    .frame(height: height)
    .accessibilityHidden(true)
  }
}

// MARK: - Lock Screen

/// Lock Screen banner (and StandBy at 2x). Uses the system background so it
/// sits on any wallpaper, with tint reserved for progress and status.
struct LockScreenTransferView: View {
  let model: TransferPresentation
  @Environment(\.isLuminanceReduced) private var luminanceReduced

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 6) {
        TeleDriveMark()
          .frame(width: 15, height: 15)
          .foregroundStyle(.secondary)
        Text("TeleDrive")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        if model.isBackup {
          Text("Photo Backup")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityHidden(true)

      HStack(spacing: 12) {
        if model.isSettled {
          OutcomeBadge(model: model, diameter: 44, fillOpacity: 0.16)
        } else {
          TransferRing(model: model, diameter: 40, lineWidth: 4, symbolSize: 15, trackOpacity: 0.2)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(model.title)
            .font(.headline)
            .foregroundStyle(.primary)
          Text(model.subtitle)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        Spacer(minLength: 8)
        if model.isRunning {
          Text("\(model.percent)%")
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(luminanceReduced ? Color.primary : model.tint)
            .contentTransition(.numericText())
        } else if model.isSettled {
          OutcomeFigure(
            model: model, valueSize: 26, unitSize: 14,
            color: luminanceReduced ? Color.primary : model.tint)
        }
      }

      if model.isSettled {
        VStack(spacing: 8) {
          LinearTransferBar(
            progress: model.outcomeProgress, tint: model.tint,
            trackColor: Color.primary.opacity(0.1))
          OutcomeRow(model: model, primary: .secondary, secondary: .secondary)
        }
      }

      if model.isRunning || model.phase == .paused || model.phase == .waitingForWifi {
        VStack(spacing: 8) {
          LinearTransferBar(
            progress: model.state.progress, tint: model.tint, trackColor: Color.primary.opacity(0.1))
          if model.isRunning, let name = model.state.currentName {
            HStack(spacing: 6) {
              Image(systemName: model.kindSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              Text(name)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .privacySensitive()
              Spacer(minLength: 8)
              if model.state.totalCount > 1, !model.byteProgress.isEmpty {
                Text(model.byteProgress)
                  .font(.footnote.weight(.medium))
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .layoutPriority(1)
              }
            }
          }
        }
      }
    }
    .padding(14)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(model.accessibilitySummary)
    .activitySystemActionForegroundColor(.secondary)
  }
}
