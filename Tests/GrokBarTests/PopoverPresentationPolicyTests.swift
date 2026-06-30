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
        let typingKeyCodes: [UInt16] = [0, 8, 14, 18, 29, 35, 46, 48, 53]
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

    func testNonTypingKeysMayDismiss() {
        XCTAssertTrue(PopoverPresentationPolicy.shouldDismissForKeyEvent(type: .keyDown, keyCode: 55))
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
        guard PopoverPresentationPolicy.isMacOS27OrLater else {
            XCTAssertEqual(
                PopoverPresentationPolicy.popoverBehavior(retainFocus: false),
                .transient
            )
            return
        }

        XCTAssertEqual(
            PopoverPresentationPolicy.popoverBehavior(retainFocus: false),
            .applicationDefined
        )
    }
}