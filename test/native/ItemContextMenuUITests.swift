import XCTest

/// Runs only against tools/ios_item_preview.dart on a simulator. Fixture markers
/// are checked before interaction; these tests never operate on live Drive data.
final class ItemContextMenuUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }
  private func fixture() -> XCUIApplication {
    let app = XCUIApplication(bundleIdentifier: "com.sree.tgclouddrive")
    app.launch()
    XCTAssertTrue(app.staticTexts["Touch and hold a photo"].waitForExistence(timeout: 15))
    return app
  }
  private func capture(_ app: XCUIApplication, _ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }
  func testNativePressPreviewAndSelect() {
    let app = fixture()
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33)).press(forDuration: 0.7)
    XCTAssertTrue(app.buttons["Open"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Select"].exists)
    capture(app, "native-context-preview")
    app.buttons["Select"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["1 selected"].firstMatch.waitForExistence(timeout: 5))
    capture(app, "native-selection-toolbar")
  }
  func testFreshActionsPreviewCommitAndScroll() {
    let app = fixture()
    let point = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33))
    point.press(forDuration: 0.7)
    XCTAssertTrue(app.buttons["Star"].waitForExistence(timeout: 5))
    app.buttons["Star"].tap()
    point.press(forDuration: 0.7)
    XCTAssertTrue(app.buttons["Unstar"].waitForExistence(timeout: 5))
    // The preview occupies the same source region above the menu.
    point.tap()
    XCTAssertTrue(app.staticTexts["Opened photo 0"].waitForExistence(timeout: 5))
    app.swipeUp()
    XCTAssertFalse(app.images["Photo 0"].isHittable)
  }
  func testOverflowAndDisabledSelectionActions() {
    let app = fixture()
    app.buttons["More"].tap()
    XCTAssertTrue(app.buttons["View as"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Sort by"].exists)
    capture(app, "native-overflow-menu")
    app.buttons["Select"].tap()
    XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Share"].isEnabled)
    app.images["Photo 0"].tap()
    XCTAssertTrue(app.buttons["Share"].isEnabled)
    app.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["More"].exists)
  }
}
