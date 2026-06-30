import XCTest
@testable import GrokBar

final class PopoverSessionControllerTests: XCTestCase {
    private func controllerShownOnMacOS27() -> PopoverSessionController {
        let controller = PopoverSessionController(osMajorVersion: 27)
        controller.prepareForTestingShown()
        return controller
    }

    func testHandleLocalKeyDownConsumesSpaceOnMacOS27() {
        let controller = controllerShownOnMacOS27()

        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown
            ),
            .consumeAndInsertSpace
        )
    }

    func testHandleLocalKeyDownPassesSpaceThroughOnMacOS14() {
        let controller = PopoverSessionController(osMajorVersion: 14)
        controller.prepareForTestingShown()

        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown
            ),
            .passThrough
        )
    }

    func testHandleLocalKeyDownClosesOnEscape() {
        let controller = controllerShownOnMacOS27()

        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.escapeKeyCode,
                eventType: .keyDown
            ),
            .close(.escapeKey)
        )
    }

    func testHandleLocalKeyDownIgnoresKeysWhenHidden() {
        let controller = PopoverSessionController(osMajorVersion: 27)

        XCTAssertEqual(
            controller.handleLocalKeyDown(
                keyCode: PopoverPresentationPolicy.spaceKeyCode,
                eventType: .keyDown
            ),
            .passThrough
        )
    }

    func testCloseWithStatusItemToggleClearsShownState() {
        let controller = controllerShownOnMacOS27()

        controller.close(reason: .statusItemToggle)

        XCTAssertFalse(controller.isShown)
    }

    func testSystemCloseRequestDoesNotClearShownState() {
        let controller = controllerShownOnMacOS27()

        controller.close(reason: .systemRequest)

        XCTAssertTrue(controller.isShown)
    }

    func testMacOS27UsesAnchoredPanelPresentation() {
        let controller = PopoverSessionController(osMajorVersion: 27)
        let hostingController = NSViewController()
        hostingController.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        controller.configure(hostingController: hostingController)

        XCTAssertTrue(PopoverPresentationPolicy.shouldUseAnchoredPanel(osMajorVersion: 27))
        XCTAssertEqual(
            PopoverPresentationPolicy.popoverBehavior(retainFocus: false, osMajorVersion: 27),
            .applicationDefined
        )
        XCTAssertTrue(
            PopoverPresentationPolicy.shouldActivateApplicationOnShow(osMajorVersion: 27)
        )
    }

    func testAnchoredFrameAnchorsBelowStatusItem() {
        let anchor = NSRect(x: 500, y: 900, width: 22, height: 22)
        let contentSize = NSSize(width: 420, height: 640)

        let frame = PopoverPresentationPolicy.panelFrame(anchor: anchor, contentSize: contentSize)

        XCTAssertEqual(frame.size, contentSize)
        XCTAssertEqual(frame.maxY, anchor.minY)
        XCTAssertEqual(frame.midX, anchor.midX, accuracy: 0.5)
    }

    func testSpaceInsertionScriptTargetsEditableElements() {
        XCTAssertTrue(PopoverPresentationPolicy.spaceInsertionScript.contains("document.activeElement"))
        XCTAssertTrue(PopoverPresentationPolicy.spaceInsertionScript.contains("INPUT"))
        XCTAssertTrue(PopoverPresentationPolicy.spaceInsertionScript.contains("TEXTAREA"))
        XCTAssertTrue(PopoverPresentationPolicy.spaceInsertionScript.contains("isContentEditable"))
    }
}