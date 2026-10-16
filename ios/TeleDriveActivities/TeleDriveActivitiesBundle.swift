import SwiftUI
import WidgetKit

/// Live Activities only; TeleDrive offers no Home Screen widgets.
@main
struct TeleDriveActivitiesBundle: WidgetBundle {
  var body: some Widget {
    TransferLiveActivity()
  }
}
