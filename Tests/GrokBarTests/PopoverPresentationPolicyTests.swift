import XCTest
@testable import GrokBar

final class PopoverPresentationPolicyTests: XCTestCase {
    func testSpaceKeyIsTypingKeyAndDoesNotDismiss() {
        XCTAssertTrue(PopoverPresentationPolicy.isTypingKeyCode(PopoverPresentationPolicy.spaceKeyCode))
        XCTAssertFalse(
            PopoverPresentationPolicy.shouldDismissForKeyEvent(
                type: .keyDown,
                keyCode: PopoverPresentationPolicy.spaceKeyCode
            )
        )
    }

    func testLetterAndNumberKeysDoNotDismiss() {
        let typingKeyCodes: [UInt16] = [0, 8, 14, 18, 29, 35, 46, 48, 52]
        for keyCode in typingKeyCodes {
            XCTAssertTrue(
                PopoverPresentationPolicy.isTypingKeyCode(keyCode),
                "Expected keyCode \(keyCode) to be treated as typing input"
            )
            XCTAssertFalse(
                PopoverPresentationPolicy.shouldDismissForKeyEvent(type: .keyDown, keyCode: keyCode),
                "Expected keyCode \(keyCode) not to dismiss the popup"
            )
        }
    }

    func testEscapeDismissesButIsNotTyping() {
        XCTAssertFalse(PopoverPresentationPolicy.isTypingKeyCode(PopoverPresentationPolicy.escapeKeyCode))
        XCTAssertTrue(
            PopoverPresentationPolicy.shouldDismissForKeyEvent(
                type: .keyDown,
                keyCode: PopoverPresentationPolicy.escapeKeyCode
            )
        )
        XCTAssertEqual(
            PopoverPresentationPolicy.closeReason(forKeyCode: PopoverPresentationPolicy.escapeKeyCode),
            .escapeKey
        )
    }

    func testNonTypingKeysMayDismiss() {
        XCTAssertTrue(PopoverPresentationPolicy.shouldDismissForKeyEvent(type: .keyDown, keyCode: 55))
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

    func testSystemCloseRequestsAreBlocked() {
        XCTAssertFalse(PopoverPresentationPolicy.shouldClosePopover(for: .systemRequest))
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

    func testRetainFocusSelectsApplicationDefinedBehavior() {
        XCTAssertEqual(
            PopoverPresentationPolicy.popoverBehavior(retainFocus: true),
            .applicationDefined
        )
    }

    func testMacOS27ForcesApplicationDefinedBehaviorEvenWithoutRetainFocus() {
        XCTAssertEqual(
            PopoverPresentationPolicy.popoverBehavior(retainFocus: false, osMajorVersion: 14),
            .transient
        )
        XCTAssertEqual(
            PopoverPresentationPolicy.popoverBehavior(retainFocus: false, osMajorVersion: 27),
            .applicationDefined
        )
    }

    func testMacOS27ConsumesSpaceInKeyMonitorAction() {
        XCTAssertEqual(
            PopoverPresentationPolicy.keyMonitorAction(
                isPopupActive: true,
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown,
                osMajorVersion: 27
            ),
            .consumeAndInsertSpace
        )
    }

    func testMacOS14PassesSpaceThroughInKeyMonitorAction() {
        XCTAssertEqual(
            PopoverPresentationPolicy.keyMonitorAction(
                isPopupActive: true,
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown,
                osMajorVersion: 14
            ),
            .passThrough
        )
    }

    func testInactivePopupIgnoresSpaceMonitorAction() {
        XCTAssertEqual(
            PopoverPresentationPolicy.keyMonitorAction(
                isPopupActive: false,
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown,
                osMajorVersion: 27
            ),
            .passThrough
        )
    }

    func testShouldUseAnchoredPanelOnlyOnMacOS27() {
        XCTAssertFalse(PopoverPresentationPolicy.shouldUseAnchoredPanel(osMajorVersion: 14))
        XCTAssertTrue(PopoverPresentationPolicy.shouldUseAnchoredPanel(osMajorVersion: 27))
    }
}