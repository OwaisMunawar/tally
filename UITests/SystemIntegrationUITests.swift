import XCTest

/// Adds the home-screen widget and the Control Center control by driving
/// SpringBoard the way a user would, then uses each one.
final class SystemIntegrationUITests: ScreenshotHarness {
    @MainActor
    func testHomeScreenWidget() {
        let app = launchTally([])
        waitFor(app.staticTexts["Net worth"])
        XCUIDevice.shared.press(.home)
        dismissKeyboardTip()

        // Long-press empty wallpaper to enter edit mode, then Edit > Add Widget.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 1.6)
        waitFor(springboard.buttons["Edit"]).tap()
        waitFor(element("Add Widget")).tap()
        let search = waitFor(springboard.searchFields.firstMatch)
        search.tap()
        search.typeText("Tally")
        waitFor(element("Tally", type: .cell)).tap()
        // Swipe to the medium size, which carries the one-tap purchase buttons.
        springboard.swipeLeft()
        waitFor(element("Add Widget", type: .button)).tap()
        waitFor(springboard.buttons["Done"]).tap()
        checkpoint("widget")

        // A preset button logs the purchase in the extension, without opening the app,
        // and the widget reloads with less left to spend.
        let left = waitFor(springboard.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'left of'")).firstMatch)
        let remaining = left.label
        let before = springboard.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$'")).firstMatch.label
        waitFor(springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Log '")).firstMatch).tap()
        let changed = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                self.springboard.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '$'")).firstMatch.label != before
            }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: changed, evaluatedWith: nil)], timeout: 20), .completed, "Still \(remaining)")
        checkpoint("widget-after-preset")
    }

    @MainActor
    func testControlCenterControl() {
        let app = launchTally([])
        waitFor(app.staticTexts["Net worth"])
        XCUIDevice.shared.press(.home)
        dismissKeyboardTip()

        openControlCenter()
        // Long-press empty space in Control Center to customise it.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).press(forDuration: 1.6)
        waitFor(element("Add a Control")).tap()
        let search = waitFor(springboard.searchFields.firstMatch)
        search.tap()
        search.typeText("Add Expense")
        checkpoint("control-gallery")
        waitFor(element("Add Expense", type: .button)).tap()
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        checkpoint("control")

        // Tapping the control should open Tally straight into the add sheet.
        waitFor(element("Add Expense", type: .button)).tap()
        waitFor(app.staticTexts["New Transaction"], timeout: 15)
        checkpoint("control-opened-app")
    }

    @MainActor
    private func element(_ label: String, type: XCUIElement.ElementType = .any) -> XCUIElement {
        springboard.descendants(matching: type).matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }

    /// First keyboard use on a fresh simulator shows a slide-to-type tip sheet.
    @MainActor
    private func dismissKeyboardTip() {
        let tip = springboard.buttons["Continue"]
        if tip.waitForExistence(timeout: 2) { tip.tap() }
    }

    @MainActor
    private func openControlCenter() {
        let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.005))
        start.press(forDuration: 0.05, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.6)))
    }
}
