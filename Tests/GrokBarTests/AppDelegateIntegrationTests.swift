import XCTest
@testable import GrokBar

final class AppDelegateIntegrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

    func testTogglePopoverOpensAndClosesThroughAppDelegate() throws {
        let controller = PopoverSessionController()
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)
        XCTAssertTrue(controller.isPopupActive)
        XCTAssertTrue(controller.presentationWindow is MenuBarPopupPanel)

        waitUntil("popup opens through app delegate") { controller.isShown }
        delegate.togglePopover(nil)
        waitUntil("popup closes through app delegate") { !controller.isPopupActive }
    }

    func testApplyPopoverSizeUsesPopupControllerWindow() throws {
        let controller = PopoverSessionController()
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)

        delegate.applyPopoverSize(animated: false)
        XCTAssertNotNil(controller.presentationWindow)
    }

    func testResizeHandleIsPositionedAtBottomLeft() throws {
        let controller = PopoverSessionController()
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)
        guard let contentView = controller.presentationWindow?.contentView else {
            return XCTFail("Popup content view was not created")
        }
        contentView.layoutSubtreeIfNeeded()
        guard let handle = findResizeHandle(in: contentView) else {
            return XCTFail("Resize handle was not created")
        }

        let handleFrame = handle.convert(handle.bounds, to: contentView)
        XCTAssertLessThan(handleFrame.midX, contentView.bounds.midX)
        XCTAssertLessThan(handleFrame.midY, contentView.bounds.midY)
        XCTAssertEqual(handleFrame.minX, contentView.bounds.minX, accuracy: 0.5)
        XCTAssertEqual(handleFrame.minY, contentView.bounds.minY, accuracy: 0.5)
        XCTAssertEqual(handleFrame.width, 28, accuracy: 0.5)
        XCTAssertEqual(handleFrame.height, 28, accuracy: 0.5)

        controller.close(reason: .statusItemToggle)
    }

    private func findResizeHandle(in view: NSView) -> ResizeHandleView? {
        if let handle = view as? ResizeHandleView { return handle }
        for subview in view.subviews {
            if let handle = findResizeHandle(in: subview) { return handle }
        }
        return nil
    }
}
