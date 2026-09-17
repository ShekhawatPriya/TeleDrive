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
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33)).press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["Open"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Select"].exists)
    let preview = app.otherElements["Preview"].firstMatch
    XCTAssertTrue(preview.waitForExistence(timeout: 10))
    XCTAssertGreaterThan(preview.frame.height, 150)
    XCTAssertFalse(app.descendants(matching: .any)["Preview unavailable"].firstMatch.exists)
    capture(app, "native-context-preview")
    app.buttons["Select"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["1 Item"].firstMatch.waitForExistence(timeout: 5))
    capture(app, "native-selection-toolbar")
    app.buttons["Select All"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["16 Items"].firstMatch.waitForExistence(timeout: 5))
    app.buttons["Selection options"].tap()
    XCTAssertTrue(app.buttons["Deselect All"].waitForExistence(timeout: 5))
    app.buttons["Deselect All"].tap()
    XCTAssertFalse(app.buttons["Share"].isEnabled)
  }
  func testFreshActionsPreviewCommitAndScroll() {
    let app = fixture()
    let point = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33))
    point.press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["Star"].waitForExistence(timeout: 5))
    app.buttons["Star"].tap()
    point.press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["Unstar"].waitForExistence(timeout: 5))
    // UIKit can move/shrink the preview to fit the menu and device.
    let preview = app.otherElements["Preview"].firstMatch
    XCTAssertTrue(preview.waitForExistence(timeout: 10))
    preview.tap()
    XCTAssertTrue(app.staticTexts["Opened photo 0"].waitForExistence(timeout: 5))
    app.swipeUp()
    XCTAssertFalse(app.images["Photo 0"].isHittable)
  }
  func testDocumentPreviewAndUnsupportedFallback() {
    let app = fixture()
    capture(app, "native-header-control-sizes")
    app.buttons["More"].tap()
    app.buttons["PDF fixture"].tap()
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33)).press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["Open"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.otherElements["Preview"].firstMatch.waitForExistence(timeout: 15))
    // UIKit exposes the whole preview as one AX container; inspect the saved
    // screenshot for document/image content rather than querying UIImageView.
    XCTAssertFalse(app.descendants(matching: .any)["Preview unavailable"].firstMatch.exists)
    capture(app, "native-pdf-preview")
    let expandedHeight = app.otherElements["Preview"].firstMatch.frame.height
    let menu = app.collectionViews.containing(.button, identifier: "Select").firstMatch
    XCTAssertTrue(menu.exists, app.debugDescription)
    let visibleMenu = menu.frame.intersection(app.frame.insetBy(dx: 0, dy: 60))
    let origin = app.coordinate(withNormalizedOffset: .zero)
    let start = origin.withOffset(CGVector(dx: visibleMenu.maxX - 15, dy: visibleMenu.maxY - 30))
    let end = origin.withOffset(CGVector(dx: visibleMenu.maxX - 15, dy: visibleMenu.minY + 30))
    start.press(forDuration: 0.05, thenDragTo: end)
    capture(app, "native-pdf-preview-scrolled")
    XCTAssertFalse(app.buttons["Done"].exists)
    XCTAssertTrue(app.buttons["Delete"].isHittable)
    let collapsed = app.otherElements["Preview"].firstMatch
    XCTAssertTrue(collapsed.exists)
    XCTAssertLessThan(collapsed.frame.height, expandedHeight)
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.12)).tap()
    XCTAssertTrue(app.buttons["More"].waitForExistence(timeout: 5))
    app.buttons["More"].tap()
    app.buttons["Unsupported fixture"].tap()
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33)).press(forDuration: 1.2)
    XCTAssertTrue(app.buttons["Open"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["Preview unavailable"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertFalse(app.images["teledrive.context.preview.image"].exists)
    capture(app, "native-unsupported-preview")
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
    let firstRow = app.descendants(matching: .any)["Photo 0"].firstMatch.frame
    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: firstRow.midX, dy: firstRow.midY)).tap()
    XCTAssertTrue(app.buttons["Share"].isEnabled)
    app.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["More"].exists)
  }
}
