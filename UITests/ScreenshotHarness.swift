import XCTest

/// Base class for the screenshot and system-integration UI tests.
///
/// At each `checkpoint` the test pauses so the capture script can take the
/// shot with `xcrun simctl io <device> screenshot` from outside the runner.
/// The script passes `TEST_RUNNER_CHECKPOINT_DIR` to xcodebuild; the test drops
/// a marker file there and waits until the script deletes it. Without that
/// variable a checkpoint just attaches an XCTest screenshot to the result bundle.
class ScreenshotHarness: XCTestCase {
    @MainActor var springboard: XCUIApplication {
        XCUIApplication(bundleIdentifier: "com.apple.springboard")
    }

    @MainActor
    func launchTally(_ arguments: [String]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"] + arguments
        app.launch()
        return app
    }

    @MainActor
    func checkpoint(_ name: String, timeout: TimeInterval = 60) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = ProcessInfo.processInfo.environment["CHECKPOINT_DIR"] else { return }
        let marker = URL(filePath: directory).appending(path: name)
        FileManager.default.createFile(atPath: marker.path(), contents: nil)
        let deadline = Date.now.addingTimeInterval(timeout)
        while FileManager.default.fileExists(atPath: marker.path()), Date.now < deadline {
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    @MainActor
    @discardableResult
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Timed out waiting for \(element)", file: file, line: line)
        return element
    }
}
