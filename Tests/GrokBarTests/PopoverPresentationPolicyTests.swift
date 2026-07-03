import XCTest
@testable import GrokBar

final class PopoverPresentationPolicyTests: XCTestCase {
    func testEscapeClosesPopup() {
        XCTAssertEqual(
            PopoverPresentationPolicy.closeReason(forKeyCode: PopoverPresentationPolicy.escapeKeyCode),
            .escapeKey
        )
    }

    func testOtherKeysPassThrough() {
        let keyCodes: [UInt16] = [0, 8, 14, 18, 29, 35, 46, 48, 52, 55, 123]
        for keyCode in keyCodes {
            XCTAssertEqual(
                PopoverPresentationPolicy.keyMonitorAction(isPopupActive: true, keyCode: keyCode),
                .passThrough
            )
        }
    }

    func testIntentionalCloseReasonsAreAllowed() {
        XCTAssertTrue(PopoverPresentationPolicy.shouldClosePopover(for: .statusItemToggle))
        XCTAssertTrue(PopoverPresentationPolicy.shouldClosePopover(for: .outsideClick, retainFocus: false))
        XCTAssertTrue(PopoverPresentationPolicy.shouldClosePopover(for: .escapeKey))
    }

    func testRetainFocusSuppressesOutsideClickDismiss() {
        XCTAssertFalse(PopoverPresentationPolicy.shouldClosePopover(for: .outsideClick, retainFocus: true))
        XCTAssertFalse(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .leftMouseDown,
                screenLocation: NSPoint(x: 10, y: 10),
                popoverFrame: NSRect(x: 100, y: 100, width: 300, height: 400),
                statusItemFrame: NSRect(x: 900, y: 1100, width: 24, height: 24),
                retainFocus: true
            )
        )
    }

    func testPanelFrameAnchorsTopRightOfVisibleScreen() {
        let visibleFrame = NSRect(x: 0, y: 100, width: 1920, height: 980)
        let contentSize = NSSize(width: 420, height: 640)
        let frame = PopoverPresentationPolicy.panelFrame(visibleFrame: visibleFrame, contentSize: contentSize)

        XCTAssertEqual(frame.maxX, visibleFrame.maxX - PopoverPresentationPolicy.screenMargin, accuracy: 0.5)
        XCTAssertEqual(frame.maxY, visibleFrame.maxY - PopoverPresentationPolicy.screenMargin, accuracy: 0.5)
        XCTAssertEqual(frame.width, contentSize.width, accuracy: 0.5)
        XCTAssertEqual(frame.height, contentSize.height, accuracy: 0.5)
    }

    func testMouseDownOutsideDismissesButInsideDoesNot() {
        let popoverFrame = NSRect(x: 100, y: 100, width: 300, height: 400)
        let statusItemFrame = NSRect(x: 900, y: 1100, width: 24, height: 24)

        XCTAssertTrue(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .leftMouseDown,
                screenLocation: NSPoint(x: 50, y: 50),
                popoverFrame: popoverFrame,
                statusItemFrame: statusItemFrame
            )
        )

        XCTAssertFalse(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .leftMouseDown,
                screenLocation: NSPoint(x: 150, y: 150),
                popoverFrame: popoverFrame,
                statusItemFrame: statusItemFrame
            )
        )

        XCTAssertFalse(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .leftMouseDown,
                screenLocation: NSPoint(x: 910, y: 1110),
                popoverFrame: popoverFrame,
                statusItemFrame: statusItemFrame
            )
        )
    }

    func testKeyEventsNeverTriggerOutsideClickDismiss() {
        XCTAssertFalse(
            PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: .keyDown,
                screenLocation: .zero,
                popoverFrame: .zero,
                statusItemFrame: nil
            )
        )
    }

    func testActivePopupConsumesSpaceInKeyMonitorAction() {
        XCTAssertEqual(
            PopoverPresentationPolicy.keyMonitorAction(
                isPopupActive: true,
                keyCode: PopoverPresentationPolicy.spaceKeyCode
            ),
            .consumeAndInsertSpace
        )
    }

    func testInactivePopupIgnoresSpaceMonitorAction() {
        XCTAssertEqual(
            PopoverPresentationPolicy.keyMonitorAction(
                isPopupActive: false,
                keyCode: PopoverPresentationPolicy.spaceKeyCode
            ),
            .passThrough
        )
    }
}
