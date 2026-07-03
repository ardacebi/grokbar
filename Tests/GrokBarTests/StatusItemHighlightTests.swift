import XCTest
@testable import GrokBar

final class StatusItemHighlightTests: XCTestCase {
    func testClearUnhighlightsStatusItemButton() {
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        button.highlight(true)
        XCTAssertTrue(button.isHighlighted)

        StatusItemHighlight.clear(on: button)

        let expectation = expectation(description: "deferred clear")
        DispatchQueue.main.async {
            XCTAssertFalse(button.isHighlighted)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testCloseNotifiesPopupInactive() {
        let controller = PopoverSessionController()
        var activeStates: [Bool] = []
        controller.onPopupActiveChanged = { activeStates.append($0) }

        let hostingController = NSViewController()
        hostingController.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        controller.configure(hostingController: hostingController)

        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        let expectation = self.expectation(description: "close notifies inactive")
        func closeWhenShown(attemptsRemaining: Int) {
            if controller.isShown {
                controller.close(reason: .statusItemToggle)
                XCTAssertTrue(activeStates.contains(true))
                XCTAssertEqual(activeStates.last, false)
                expectation.fulfill()
                return
            }

            guard attemptsRemaining > 0 else {
                XCTFail("Popup did not finish opening")
                expectation.fulfill()
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                closeWhenShown(attemptsRemaining: attemptsRemaining - 1)
            }
        }

        closeWhenShown(attemptsRemaining: 40)
        wait(for: [expectation], timeout: 3.0)
    }
}
