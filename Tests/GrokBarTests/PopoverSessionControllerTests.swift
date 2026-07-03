import XCTest
@testable import GrokBar

final class PopoverSessionControllerTests: XCTestCase {
    private func configuredController() -> PopoverSessionController {
        let controller = PopoverSessionController()
        let hostingController = NSViewController()
        hostingController.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        controller.configure(hostingController: hostingController)
        return controller
    }

    func testShowActivatesPopupAndStartsMonitorsBeforeAnimationCompletes() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!

        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        XCTAssertTrue(controller.isPopupActive)
        XCTAssertTrue(controller.isOpening)
        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.spaceKeyCode
            ),
            .consumeAndInsertSpace
        )

        waitUntil("open animation") { controller.isShown }
        XCTAssertFalse(controller.isOpening)
    }

    func testToggleInterruptsAnimationToClose() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        let contentSize = NSSize(width: 420, height: 640)

        controller.show(relativeTo: button, contentSize: contentSize)
        XCTAssertTrue(controller.isAnimating)

        controller.toggle(relativeTo: button, contentSize: contentSize)

        waitUntil("toggle closes during animation") { !controller.isPopupActive }
    }

    func testRapidToggleReopensDuringCloseAnimation() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        let contentSize = NSSize(width: 420, height: 640)

        controller.show(relativeTo: button, contentSize: contentSize)

        let openedExpectation = expectation(description: "opened")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            controller.toggle(relativeTo: button, contentSize: contentSize)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                controller.toggle(relativeTo: button, contentSize: contentSize)
                openedExpectation.fulfill()
            }
        }

        wait(for: [openedExpectation], timeout: 2.0)

        let shownExpectation = expectation(description: "shown after reverse")
        func waitUntilShown(attemptsRemaining: Int) {
            if controller.isShown {
                shownExpectation.fulfill()
                return
            }

            guard attemptsRemaining > 0 else {
                XCTFail("Popup did not finish reopening")
                shownExpectation.fulfill()
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                waitUntilShown(attemptsRemaining: attemptsRemaining - 1)
            }
        }

        waitUntilShown(attemptsRemaining: 40)
        wait(for: [shownExpectation], timeout: 3.0)
        XCTAssertTrue(controller.isPopupActive)
    }

    func testRetainFocusPreventsOutsideClickClose() {
        let controller = configuredController()
        controller.retainFocus = true
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!

        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        controller.close(reason: .outsideClick)
        XCTAssertTrue(controller.isPopupActive)
    }

    func testAnchoredFrameUsesTopRightVisibleScreen() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        let contentSize = NSSize(width: 420, height: 640)
        let screen = button.window?.screen ?? NSScreen.main!
        let expected = PopoverPresentationPolicy.panelFrame(
            visibleFrame: screen.visibleFrame,
            contentSize: contentSize
        )

        XCTAssertEqual(controller.anchoredFrame(for: button, contentSize: contentSize), expected)
    }

    func testHandleLocalKeyDownClosesOnEscapeWhenActive() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.escapeKeyCode
            ),
            .close(.escapeKey)
        )
    }

    func testToggleCloseClearsShownState() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        let contentSize = NSSize(width: 420, height: 640)

        controller.show(relativeTo: button, contentSize: contentSize)

        waitUntil("opened before toggle close") { controller.isShown }
        controller.toggle(relativeTo: button, contentSize: contentSize)
        waitUntil("closed after toggle") { !controller.isPopupActive }
    }

    func testUsesAnchoredPanelPresentation() {
        let controller = configuredController()

        XCTAssertTrue(controller.presentationWindow is MenuBarPopupPanel)
    }

    func testSpaceInsertionScriptIncludesGrokPromptFallbackSelectors() {
        XCTAssertTrue(PopoverPresentationPolicy.spaceInsertionScript.contains("[role=\"textbox\"]"))
        XCTAssertTrue(PopoverPresentationPolicy.spaceInsertionScript.contains("querySelectorAll"))
    }
}
