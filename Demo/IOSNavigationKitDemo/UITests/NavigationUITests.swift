import XCTest

@MainActor
final class NavigationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Push detail screen"].waitForExistence(timeout: 10))
        return app
    }

    // Regression: an idle legacy toast drag recognizer consumed the first native
    // Back tap on iOS 26.2. Each iteration performs exactly one tap.
    func testSingleBackTapRepeatedly() {
        let app = launch()
        for cycle in 0..<8 {
            app.buttons["Push detail screen"].tap()
            XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
            if cycle % 2 == 1 { app.buttons["Show persistent toast"].tap() }
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["Push detail screen"].waitForExistence(timeout: 5), "Back failed on cycle \(cycle)")
            if cycle % 2 == 1 { app.buttons["demo.toast"].tap() }
        }
    }

    func testInteractiveBack() {
        let app = launch()
        app.buttons["Push detail screen"].tap()
        XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.buttons["Push detail screen"].waitForExistence(timeout: 5))
    }

    func testProgrammaticPopAndPopToRoot() {
        let app = launch()
        app.buttons["Push detail screen"].tap()
        app.buttons["Push another detail"].tap()
        XCTAssertTrue(app.navigationBars["Detail 2"].waitForExistence(timeout: 5))
        app.buttons["Pop one screen"].tap()
        XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Explore stack depth: 1"].exists)
        app.buttons["Push another detail"].tap()
        app.buttons["Push another detail"].tap()
        XCTAssertTrue(app.navigationBars["Detail 3"].waitForExistence(timeout: 5))
        app.buttons["Pop to Explore root"].tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        app.buttons["Push detail screen"].tap()
        XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Explore stack depth: 1"].exists)
    }
    func testCancelledInteractiveBackThenSingleTap() {
        let app = launch()
        app.buttons["Push detail screen"].tap()
        XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
        app.buttons["Push another detail"].tap()
        XCTAssertTrue(app.navigationBars["Detail 2"].waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let partial = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: partial, withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(app.navigationBars["Detail 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Explore stack depth: 2"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Explore stack depth: 1"].exists)
    }

    func testIndependentTabsAndNestedBack() {
        let app = launch()
        app.buttons["Push detail screen"].tap()
        XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Profile"].tap()
        app.buttons["Push Settings"].tap()
        app.buttons["Push Preferences"].tap()
        XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
        app.buttons["Open nested workspace"].tap()
        XCTAssertTrue(app.buttons["Push workspace item"].waitForExistence(timeout: 5))
        app.buttons["Push workspace item"].tap()
        XCTAssertTrue(app.navigationBars["Item 1"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Close workspace"].waitForExistence(timeout: 5))
        app.buttons["Close workspace"].tap()
        XCTAssertTrue(app.navigationBars["Detail 1"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Preferences"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testSharedToastRemainsAboveNestedFullScreenSurface() {
        let app = launch()
        app.buttons["Open full-screen workspace"].tap()
        XCTAssertTrue(app.buttons["Close workspace"].waitForExistence(timeout: 5))

        app.buttons["showPersistentToast.Workspace"].tap()
        let toast = app.buttons["demo.toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(toast.label.contains("Workspace"))
        XCTAssertGreaterThan(toast.frame.midY, app.frame.height * 0.65)

        app.buttons["Close workspace"].tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        XCTAssertTrue(toast.label.contains("Workspace"))
        XCTAssertGreaterThan(toast.frame.midY, app.frame.height * 0.65)
        toast.tap()
        XCTAssertFalse(toast.exists)
    }

}
