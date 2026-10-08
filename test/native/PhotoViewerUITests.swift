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
    let player = app.otherElements.matching(NSPredicate(format: "label == %@", "Video")).firstMatch
    XCTAssertTrue(player.waitForExistence(timeout: 10), app.debugDescription)
    let pause = app.buttons["Play/Pause"]
    revealControls(player, until: pause)
    XCTAssertTrue(pause.exists, app.debugDescription)
    assertPlaybackAdvances(app)
    XCTAssertEqual(app.buttons["Mute/Unmute"].value as? String, "Muted")
    capture(app, "photos-native-video-controls")
    pause.tap()
    XCTAssertTrue(pause.waitForExistence(timeout: 5), app.debugDescription)
    let pausedTime = app.staticTexts["Elapsed Time"].label
    let staysPaused = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.staticTexts["Elapsed Time"].label != pausedTime }, object: nil)
    staysPaused.isInverted = true
    XCTAssertEqual(XCTWaiter.wait(for: [staysPaused], timeout: 1.2), .completed)
    let slider = app.sliders.matching(NSPredicate(format: "identifier == %@", "Current position")).firstMatch
    XCTAssertTrue(slider.exists, app.debugDescription)
    slider.adjust(toNormalizedSliderPosition: 0.45)
    XCTAssertTrue(back.exists, "Scrubbing must keep the video page open")
    capture(app, "photos-native-video-scrubbed")
    app.buttons["Fullscreen Button"].tap()
    let exitFullscreen = app.buttons.matching(NSPredicate(format: "label ==[c] %@ OR label == %@ OR label == %@", "exit full screen", "Done", "Close")).firstMatch
    if !exitFullscreen.exists { app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.3)).tap() }
    XCTAssertTrue(exitFullscreen.waitForExistence(timeout: 5), app.debugDescription)
    capture(app, "photos-native-video-fullscreen")
    exitFullscreen.tap()
    XCTAssertTrue(back.waitForExistence(timeout: 5))
    revealControls(player, until: pause)
    pause.tap()
    back.tap()
    XCTAssertTrue(app.staticTexts["Photos library fixture"].waitForExistence(timeout: 5))
    video.tap()
    XCTAssertTrue(player.waitForExistence(timeout: 10))
    let transport = app.buttons["Play/Pause"]
    revealControls(player, until: transport)
    XCTAssertTrue(transport.exists, app.debugDescription)
    assertPlaybackAdvances(app)
    capture(app, "photos-native-video-reopened")
    back.tap()
    XCTAssertTrue(app.staticTexts["Photos library fixture"].waitForExistence(timeout: 5))
  }

  private func assertPlaybackAdvances(_ app: XCUIApplication) {
    let elapsed = app.staticTexts["Elapsed Time"]
    XCTAssertTrue(elapsed.exists)
    let originalTime = elapsed.label
    let advances = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in elapsed.label != originalTime }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [advances], timeout: 3), .completed, "The active video must advance")
  }

  private func revealControls(_ player: XCUIElement, until control: XCUIElement) {
    // AVKit may start with controls visible or already auto-hidden by the time
    // XCTest finishes waiting for the presentation to become idle.
    for _ in 0..<3 {
      if control.exists { return }
      player.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.28)).tap()
      if control.waitForExistence(timeout: 1) { return }
    }
  }

  private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
    try? app.screenshot().pngRepresentation.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name + ".png"))
  }
}
