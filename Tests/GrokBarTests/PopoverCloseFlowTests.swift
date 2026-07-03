import XCTest
@testable import GrokBar

final class PopoverCloseFlowTests: XCTestCase {
    func testStatusItemToggleUsesAllowedCloseReason() {
        XCTAssertTrue(
            PopoverPresentationPolicy.shouldClosePopover(for: .statusItemToggle),
            "Clicking the menu-bar icon again must be allowed to close the popup"
        )
    }

    func testCloseFlowConsumesSpaceAndAllowsToggle() {
        let controller = PopoverSessionController()
        let hostingController = NSViewController()
        hostingController.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        controller.configure(hostingController: hostingController)

        let button = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength).button!
        controller.show(relativeTo: button, contentSize: NSSize(width: 420, height: 640))

        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.spaceKeyCode
            ),
            .consumeAndInsertSpace
        )
        XCTAssertTrue(PopoverPresentationPolicy.shouldClosePopover(for: .statusItemToggle))
    }

    func testOutsideClickDismissesOnlyWhenRetainFocusIsOff() {
        let popoverFrame = NSRect(x: 100, y: 100, width: 300, height: 400)
        let statusItemFrame = NSRect(x: 900, y: 1100, width: 24, height: 24)
        let outsidePoint = NSPoint(x: 10, y: 10)

        XCTAssertTrue(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .leftMouseDown,
                screenLocation: outsidePoint,
                popoverFrame: popoverFrame,
                statusItemFrame: statusItemFrame,
                retainFocus: false
            )
        )
        XCTAssertFalse(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .leftMouseDown,
                screenLocation: outsidePoint,
                popoverFrame: popoverFrame,
                statusItemFrame: statusItemFrame,
                retainFocus: true
            )
        )
        XCTAssertTrue(PopoverPresentationPolicy.shouldClosePopover(for: .outsideClick, retainFocus: false))
        XCTAssertFalse(PopoverPresentationPolicy.shouldClosePopover(for: .outsideClick, retainFocus: true))
    }

    func testStatusItemClickIsExcludedFromOutsideDismissMonitor() {
        let popoverFrame = NSRect(x: 100, y: 100, width: 300, height: 400)
        let statusItemFrame = NSRect(x: 900, y: 1100, width: 24, height: 24)

        XCTAssertFalse(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .leftMouseDown,
                screenLocation: NSPoint(x: 910, y: 1110),
                popoverFrame: popoverFrame,
                statusItemFrame: statusItemFrame
            ),
            "Status-item clicks must be handled by togglePopover, not the outside-click monitor"
        )
    }
}
