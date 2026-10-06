import XCTest

/// Simulator-only: tools/ios_photo_viewer_preview.dart has no live account.
final class PhotosLibraryControlsUITests: XCTestCase {
  func testSearchDisclosureUsesNativeKeyboardAndReturnsToCategory() {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "com.sree.tgclouddrive")
    app.launch()
    XCTAssertTrue(app.buttons["Browse fixture library"].waitForExistence(timeout: 20))
    app.buttons["Browse fixture library"].tap()
    let videos = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Videos")).firstMatch
    XCTAssertTrue(videos.waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "photos-categories")).firstMatch.exists, "The categories must be hosted as native UIKit controls")
    XCTAssertGreaterThanOrEqual(videos.frame.height, 44)
    capture(app, "photos-native-glass-categories-dark")
    app.buttons["All media"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(forDuration: 0.05, thenDragTo: videos.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
    XCTAssertTrue(videos.isSelected, "A native horizontal drag must select its release category")
    let video = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Fixture video.mp4")).firstMatch
    XCTAssertTrue(video.waitForExistence(timeout: 5))
    let search = app.buttons["Search photos and videos"]
    search.tap()
    let field = app.descendants(matching: .any)["drive-search-field"].firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Disclosure must focus UIKit without a second tap")
    XCTAssertFalse(videos.exists)
    field.typeText("not found")
    submitSearch(app)
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertEqual(field.value as? String, "not found")
    XCTAssertFalse(video.exists)
    let cancel = app.buttons["drive-search-cancel"]
    XCTAssertTrue(cancel.isHittable)
    capture(app, "photos-native-glass-search-expanded")
    cancel.tap()
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    XCTAssertTrue(videos.exists)
    XCTAssertTrue(video.exists, "Cancelling restores the filtered collection")
    // UIKit retains the input view for the reverse morph; it must be inert.
    XCTAssertFalse(field.isHittable)
    XCTAssertFalse(app.keyboards.firstMatch.exists)
    search.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    // Type without tapping the field again: reopening must restore its focus.
    // Exercise Return through keyboard input too (including hardware keyboards).
    field.typeText("x")
    XCTAssertEqual(field.value as? String, "x")
    field.typeText(XCUIKeyboardKey.delete.rawValue)
    field.typeText("\n")
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertTrue(cancel.isHittable)
    cancel.tap()
    XCTAssertTrue(search.waitForExistence(timeout: 5))
  }

  func testNativeCategoriesLightAndAccessibleWidth() {
    continueAfterFailure = false
    for large in [false, true] {
      let app = XCUIApplication(bundleIdentifier: "com.sree.tgclouddrive")
      app.launch()
      XCTAssertTrue(app.buttons["Browse fixture library"].waitForExistence(timeout: 20))
      app.buttons["Browse fixture library"].tap()
      if !large { app.buttons["Fixture light theme"].tap() }
      app.buttons["Fixture 320 points"].tap()
      if large { app.buttons["Fixture large text"].tap() }
      let selector = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "photos-categories")).firstMatch
      XCTAssertTrue(selector.waitForExistence(timeout: 5))
      if large { app.scrollViews["photos-category-scroll"].swipeLeft() }
      let videos = selector.buttons["Videos"]
      XCTAssertTrue(videos.isHittable, app.debugDescription)
      videos.tap()
      XCTAssertTrue(videos.isSelected)
      capture(app, large ? "photos-native-glass-categories-accessible" : "photos-native-glass-categories-light")
      app.buttons["Search photos and videos"].tap()
      let cancel = app.buttons["drive-search-cancel"]
      XCTAssertTrue(cancel.waitForExistence(timeout: 5))
      XCTAssertGreaterThanOrEqual(cancel.frame.width, 44)
      capture(app, large ? "photos-native-glass-search-accessible" : "photos-native-glass-search-light")
      cancel.tap()
      XCTAssertTrue(selector.waitForExistence(timeout: 5))
      XCTAssertTrue(videos.isSelected)
      app.terminate()
    }
  }

  private func capture(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }

  private func submitSearch(_ app: XCUIApplication) {
    let button = app.keyboards.buttons["Search"]
    // Keyboard existence precedes its slide-in animation finishing.
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: button)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    button.tap()
  }
}
