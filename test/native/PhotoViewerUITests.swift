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

  func testLibraryInteractiveReturnAndNativeVideo() {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "com.sree.tgclouddrive")
    app.launch()
    XCTAssertTrue(app.staticTexts["Photo viewer fixture"].waitForExistence(timeout: 20))
    app.buttons["Browse fixture library"].tap()
    XCTAssertTrue(app.staticTexts["Photos library fixture"].waitForExistence(timeout: 5))
    capture(app, "photos-native-library")
    let photo = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Fixture photo 0.jpg")).firstMatch
    XCTAssertTrue(photo.waitForExistence(timeout: 5), app.debugDescription)
    photo.tap()
    let back = app.buttons["Back to fixture library"]
    XCTAssertTrue(back.waitForExistence(timeout: 5))
    let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
    center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55)))
    XCTAssertTrue(back.waitForExistence(timeout: 5))
    capture(app, "photos-native-cancelled-dismissal")
    center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.87)))
    XCTAssertTrue(app.staticTexts["Photos library fixture"].waitForExistence(timeout: 5))
    let video = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Fixture video.mp4")).firstMatch
    video.tap()
    // Photos-style transport: one chrome layer, no AVKit controls.
    let pause = app.buttons["Pause"]
    XCTAssertTrue(pause.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertTrue(app.buttons["Unmute"].exists, "Videos start muted")
    XCTAssertFalse(app.buttons["Play/Pause"].exists, "AVKit transport must not appear")
    XCTAssertFalse(app.buttons["Fullscreen Button"].exists, "AVKit full screen must not appear")
    let position = app.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Playback position")).firstMatch
    XCTAssertTrue(position.exists, app.debugDescription)
    assertPlaybackAdvances(position)
    capture(app, "photos-native-video-controls")
    pause.tap()
    let play = app.buttons["Play"]
    XCTAssertTrue(play.waitForExistence(timeout: 5), app.debugDescription)
    let pausedTime = position.value as? String
    let staysPaused = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in position.value as? String != pausedTime }, object: nil)
    staysPaused.isInverted = true
    XCTAssertEqual(XCTWaiter.wait(for: [staysPaused], timeout: 1.2), .completed)
    // One tap hides every control together, as in Photos; another shows them.
    let media = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
    media.tap()
    let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !play.exists && !back.exists && !app.buttons["Share"].exists }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 3), .completed, app.debugDescription)
    capture(app, "photos-native-video-hidden-chrome")
    media.tap()
    XCTAssertTrue(play.waitForExistence(timeout: 3), app.debugDescription)
    XCTAssertTrue(back.exists)
    media.doubleTap()
    capture(app, "photos-native-video-filled")
    media.doubleTap()
    XCTAssertTrue(play.exists, "Double-tap changes fit, not chrome")
    position.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: position.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
    XCTAssertNotEqual(position.value as? String, pausedTime, "Scrubbing must move the position")
    XCTAssertTrue(back.exists, "Scrubbing must keep the video page open")
    capture(app, "photos-native-video-scrubbed")
    play.tap()
    XCTAssertTrue(pause.waitForExistence(timeout: 5))
    back.tap()
    XCTAssertTrue(app.staticTexts["Photos library fixture"].waitForExistence(timeout: 5))
    video.tap()
    XCTAssertTrue(pause.waitForExistence(timeout: 10), app.debugDescription)
    assertPlaybackAdvances(position)
    capture(app, "photos-native-video-reopened")
    back.tap()
    XCTAssertTrue(app.staticTexts["Photos library fixture"].waitForExistence(timeout: 5))
  }

  private func assertPlaybackAdvances(_ position: XCUIElement) {
    XCTAssertTrue(position.exists)
    let original = position.value as? String
    let advances = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in position.value as? String != original }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [advances], timeout: 3), .completed, "The active video must advance")
  }

  private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
    try? app.screenshot().pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name + ".png"))
  }
}
