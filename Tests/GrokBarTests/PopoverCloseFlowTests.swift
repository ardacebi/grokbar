import XCTest
@testable import GrokBar

final class PopoverCloseFlowTests: XCTestCase {
    func testStatusItemToggleUsesAllowedCloseReason() {
        XCTAssertTrue(
            PopoverPresentationPolicy.shouldClosePopover(for: .statusItemToggle),
            "Clicking the menu-bar icon again must be allowed to close the popup"
        )
    }

    func testCloseFlowBlocksIncidentalSystemDismissButAllowsToggle() {
        let controller = PopoverSessionController(osMajorVersion: 27)
        controller.prepareForTestingShown()

        XCTAssertFalse(PopoverPresentationPolicy.shouldClosePopover(for: .systemRequest))
        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown
            ),
            .consumeAndInsertSpace
        )
        XCTAssertTrue(PopoverPresentationPolicy.shouldClosePopover(for: .statusItemToggle))
    }

    func testOutsideClickRemainsIntentionalDismiss() {
        let popoverFrame = NSRect(x: 100, y: 100, width: 300, height: 400)

        XCTAssertTrue(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .leftMouseDown,
                screenLocation: NSPoint(x: 10, y: 10),
                popoverFrame: popoverFrame,
                statusItemFrame: NSRect(x: 900, y: 1100, width: 24, height: 24)
            )
        )
        XCTAssertTrue(PopoverPresentationPolicy.shouldClosePopover(for: .outsideClick))
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