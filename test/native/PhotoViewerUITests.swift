import XCTest

/// Only tools/ios_photo_viewer_preview.dart; actions cannot mutate live data.
final class PhotoViewerUITests: XCTestCase {
  func testNativeSymbolsAndInspector() {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "com.sree.tgclouddrive")
    app.launch()
    XCTAssertTrue(app.staticTexts["Photo viewer fixture"].waitForExistence(timeout: 20))
    let details = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "Alpine afternoon.jpg")).firstMatch
    let labels = ["Share", "Add star", "Info", "Delete"]
    for label in labels {
      let button = app.buttons[label]
      XCTAssertTrue(button.waitForExistence(timeout: 5))
      XCTAssertGreaterThanOrEqual(button.frame.width, 44)
      XCTAssertGreaterThanOrEqual(button.frame.height, 44)
    }
    capture(app, "photo-native-toolbar")
    app.buttons["Add star"].tap()
    XCTAssertTrue(app.buttons["Remove star"].waitForExistence(timeout: 5))
    app.buttons["Info"].tap()
    XCTAssertTrue(details.waitForExistence(timeout: 5), app.debugDescription)
    capture(app, "photo-native-inspector")
    app.buttons["Info"].tap()
    app.buttons["Delete"].tap()
    XCTAssertTrue(app.staticTexts["Fixture delete tapped"].waitForExistence(timeout: 5))
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
    start.press(forDuration: 0.05, thenDragTo: end)
    XCTAssertTrue(details.waitForExistence(timeout: 5), app.debugDescription)
    capture(app, "photo-native-swipe-inspector")
    let handle = app.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Resize photo information")).firstMatch
    XCTAssertTrue(handle.waitForExistence(timeout: 5))
    let grip = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let expanded = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
    grip.press(forDuration: 0.05, thenDragTo: expanded)
    let collapse = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
    handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05, thenDragTo: collapse)
    capture(app, "photo-native-handle-reversal")
  }
  func testNativeCopyShareSheet() {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "com.sree.tgclouddrive")
    app.launch()
    XCTAssertTrue(app.staticTexts["Photo viewer fixture"].waitForExistence(timeout: 20))
    app.buttons["Share"].tap()
    let choice = app.descendants(matching: .any).matching(
      NSPredicate(format: "label BEGINSWITH %@", "Share a copy")).firstMatch
    XCTAssertTrue(choice.waitForExistence(timeout: 5), app.debugDescription)
    XCTAssertFalse(app.buttons["Info"].exists, "Native glass controls must not composite through the modal.")
    capture(app, "native-copy-or-link-choice")
    choice.tap()
    let copy = app.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@ OR label == %@", "Copy", "Copy Photo")).firstMatch
    XCTAssertTrue(copy.waitForExistence(timeout: 10), app.debugDescription)
    capture(app, "native-original-file-share-sheet")
    // Inspect the OS sheet only. Do not send the fixture to a recipient.
    let close = app.buttons["Close"].firstMatch
    if close.exists { close.tap() }
  }

  private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
