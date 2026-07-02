import XCTest
@testable import GrokBar

final class PopoverSessionControllerTests: XCTestCase {
    private func configuredController(osMajorVersion: Int = 27) -> PopoverSessionController {
        let controller = PopoverSessionController(osMajorVersion: osMajorVersion)
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
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown
            ),
            .consumeAndInsertSpace
        )

        let openExpectation = expectation(description: "open animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertTrue(controller.isShown)
            XCTAssertFalse(controller.isOpening)
            openExpectation.fulfill()
        }
        wait(for: [openExpectation], timeout: 2.0)
    }

    func testToggleInterruptsAnimationToClose() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        let contentSize = NSSize(width: 420, height: 640)

        controller.show(relativeTo: button, contentSize: contentSize)
        XCTAssertTrue(controller.isAnimating)

        controller.toggle(relativeTo: button, contentSize: contentSize)

        let closeExpectation = expectation(description: "toggle closes during animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            XCTAssertFalse(controller.isPopupActive)
            closeExpectation.fulfill()
        }
        wait(for: [closeExpectation], timeout: 2.0)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            XCTAssertTrue(controller.isShown)
            XCTAssertTrue(controller.isPopupActive)
            shownExpectation.fulfill()
        }
        wait(for: [shownExpectation], timeout: 2.0)
    }

    func testRetainFocusPreventsOutsideClickClose() {
        let controller = configuredController()
        controller.retainFocus = true
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!

        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        let openExpectation = expectation(description: "opened")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            controller.close(reason: .outsideClick)
            XCTAssertTrue(controller.isPopupActive)
            openExpectation.fulfill()
        }
        wait(for: [openExpectation], timeout: 2.0)
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

    func testHandleLocalKeyDownPassesSpaceThroughOnMacOS14() {
        let controller = configuredController(osMajorVersion: 14)
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown
            ),
            .passThrough
        )
    }

    func testHandleLocalKeyDownClosesOnEscapeWhenActive() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.escapeKeyCode,
                eventType: .keyDown
            ),
            .close(.escapeKey)
        )
    }

    func testToggleCloseClearsShownState() {
        let controller = configuredController()
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        let contentSize = NSSize(width: 420, height: 640)

        controller.show(relativeTo: button, contentSize: contentSize)

        let closeExpectation = expectation(description: "closed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            controller.toggle(relativeTo: button, contentSize: contentSize)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                XCTAssertFalse(controller.isPopupActive)
                closeExpectation.fulfill()
            }
        }
        wait(for: [closeExpectation], timeout: 2.0)
    }

    func testMacOS27UsesAnchoredPanelPresentation() {
        let controller = configuredController()

        XCTAssertTrue(PopoverPresentationPolicy.shouldUseAnchoredPanel(osMajorVersion: 27))
        XCTAssertTrue(controller.presentationWindow is MenuBarPopupPanel || controller.presentationWindow == nil)
    }

    func testSpaceInsertionScriptIncludesGrokPromptFallbackSelectors() {
        XCTAssertTrue(PopoverPresentationPolicy.spaceInsertionScript.contains("[role=\"textbox\"]"))
        XCTAssertTrue(PopoverPresentationPolicy.spaceInsertionScript.contains("querySelectorAll"))
    }
}