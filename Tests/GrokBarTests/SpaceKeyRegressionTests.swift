import XCTest
@testable import GrokBar

final class SpaceKeyRegressionTests: XCTestCase {
    private func configuredController(retainFocus: Bool = false) -> PopoverSessionController {
        let controller = PopoverSessionController()
        controller.retainFocus = retainFocus
        let hostingController = NSViewController()
        hostingController.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        controller.configure(hostingController: hostingController)
        return controller
    }

    func testSpaceInterceptDoesNotDependOnRetainFocus() {
        XCTAssertTrue(
            PopoverPresentationPolicy.shouldInterceptSpaceKey(isPopupActive: true)
        )
        XCTAssertEqual(
            PopoverPresentationPolicy.keyMonitorAction(
                isPopupActive: true,
                keyCode: PopoverPresentationPolicy.spaceKeyCode
            ),
            .consumeAndInsertSpace
        )
    }

    func testMonitoredKeyDownConsumesSpaceWithoutClosingWhenRetainFocusOff() {
        let controller = configuredController(retainFocus: false)
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        let passesThrough = controller.processMonitoredKeyDown(
            keyCode: PopoverPresentationPolicy.spaceKeyCode
        )

        XCTAssertFalse(passesThrough)
        XCTAssertEqual(controller.closeInvocationCount, 0)
        XCTAssertTrue(controller.isPopupActive)
    }

    func testMonitoredKeyDownStillClosesOnEscape() {
        let controller = configuredController(retainFocus: false)
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        _ = controller.processMonitoredKeyDown(
            keyCode: PopoverPresentationPolicy.escapeKeyCode
        )

        XCTAssertEqual(controller.closeInvocationCount, 1)
    }

    func testShowRegistersLocalKeyMonitor() {
        let controller = configuredController(retainFocus: false)
        XCTAssertFalse(controller.isLocalKeyMonitorActive)

        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        XCTAssertTrue(controller.isLocalKeyMonitorActive)
    }

    func testPanelSendEventConsumesSpaceWithoutClosing() {
        let controller = configuredController(retainFocus: false)
        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        guard let panel = controller.presentationWindow as? MenuBarPopupPanel else {
            XCTFail("Expected anchored panel")
            return
        }

        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: PopoverPresentationPolicy.spaceKeyCode
        ) else {
            XCTFail("Failed to create space key event")
            return
        }

        panel.sendEvent(event)

        XCTAssertEqual(controller.closeInvocationCount, 0)
        XCTAssertTrue(controller.isPopupActive)
    }
}
