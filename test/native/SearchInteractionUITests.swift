import XCTest

/// Run only with tools/ios_design_preview.dart on a simulator. This fixture has
/// no live library. Inspect the recorded native transition on an iPhone as well.
final class SearchInteractionUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }
  private func fixture() -> XCUIApplication {
    let app = XCUIApplication(bundleIdentifier: "com.sree.tgclouddrive")
    app.launch()
    XCTAssertTrue(app.staticTexts["Design preview — fixtures"].waitForExistence(timeout: 15))
    return app
  }
  func testSearchAndCancelOwnSeparateTargets() {
    let app = fixture()
    let field = app.searchFields["drive-search-field"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("Travel")
    let cancel = app.buttons["drive-search-cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    XCTAssertGreaterThanOrEqual(cancel.frame.minX - field.frame.maxX, 8)
    XCTAssertGreaterThanOrEqual(cancel.frame.width, 44)
    app.keyboards.buttons["Search"].tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertEqual(field.value as? String, "Travel")
    field.tap()
    cancel.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertFalse(cancel.isHittable)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "native-search-merged"
    shot.lifetime = .keepAlways
    add(shot)
  }
  func testLeavingSearchResignsNativeKeyboard() {
    let app = fixture()
    let field = app.searchFields["drive-search-field"]
    field.tap()
    field.typeText("Project")
    app.buttons["Account and settings"].tap()
    XCTAssertTrue(app.staticTexts["Account"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    XCTAssertFalse(app.buttons["Close"].exists)
    app.buttons["Back"].tap()
    XCTAssertTrue(app.staticTexts["Design preview — fixtures"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.keyboards.firstMatch.exists)
  }
}
