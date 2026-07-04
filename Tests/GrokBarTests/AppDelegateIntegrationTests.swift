import XCTest
import WebKit
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

    func testApplyPopoverSizeUpdatesWindowToMatchPreset() throws {
        let controller = PopoverSessionController()
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)
        waitUntil("popup opens for preset resize") { controller.isShown }

        guard let window = controller.presentationWindow else {
            return XCTFail("Popup window was not created")
        }

        let targetPreset = delegate.settings.popupSizePreset
        controller.setContentSize(PopupSizePreset.small.contentSize)
        delegate.applyPopoverSize(animated: false)

        XCTAssertEqual(window.frame.size.width, targetPreset.contentSize.width, accuracy: 1.0)
        XCTAssertEqual(window.frame.size.height, targetPreset.contentSize.height, accuracy: 1.0)

        controller.close(reason: .statusItemToggle)
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

    func testResizeHandleAppliesLiveFrameDuringDrag() throws {
        let controller = PopoverSessionController()
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)
        waitUntil("popup opens for resize drag") { controller.isShown }

        guard let window = controller.presentationWindow,
              let contentView = window.contentView else {
            return XCTFail("Popup window was not created")
        }
        contentView.layoutSubtreeIfNeeded()
        guard let handle = findResizeHandle(in: contentView) else {
            return XCTFail("Resize handle was not created")
        }

        let initialSize = window.frame.size
        let visibleFrame = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let largerFrame = PopoverPresentationPolicy.panelFrame(
            visibleFrame: visibleFrame,
            contentSize: PopupSizePreset.large.contentSize
        )

        handle.enqueueCoalescedFrameUpdate(largerFrame, for: window)
        waitUntil("resize handle applies live frame") {
            window.frame.size != initialSize
        }

        XCTAssertGreaterThan(window.frame.width, initialSize.width)
        XCTAssertGreaterThan(window.frame.height, initialSize.height)

        controller.close(reason: .statusItemToggle)
    }

    func testResizeHandleFlushesPendingFrameOnGestureEnd() throws {
        let controller = PopoverSessionController()
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)
        waitUntil("popup opens for pending frame flush") { controller.isShown }

        guard let window = controller.presentationWindow,
              let contentView = window.contentView else {
            return XCTFail("Popup window was not created")
        }
        contentView.layoutSubtreeIfNeeded()
        guard let handle = findResizeHandle(in: contentView) else {
            return XCTFail("Resize handle was not created")
        }

        let initialSize = window.frame.size
        let visibleFrame = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let largerFrame = PopoverPresentationPolicy.panelFrame(
            visibleFrame: visibleFrame,
            contentSize: PopupSizePreset.large.contentSize
        )

        handle.enqueueCoalescedFrameUpdate(largerFrame, for: window)
        handle.applyPendingFrameForTesting(for: window)

        XCTAssertGreaterThan(window.frame.width, initialSize.width)
        XCTAssertGreaterThan(window.frame.height, initialSize.height)
        XCTAssertEqual(window.frame.size.width, largerFrame.size.width, accuracy: 1.0)
        XCTAssertEqual(window.frame.size.height, largerFrame.size.height, accuracy: 1.0)

        controller.close(reason: .statusItemToggle)
    }

    func testWebContainerViewConfiguresWebViewClearBackground() throws {
        let controller = PopoverSessionController()
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)
        waitUntil("popup opens for web view background check") { controller.isShown }

        guard let contentView = controller.presentationWindow?.contentView else {
            return XCTFail("Popup content view was not created")
        }
        contentView.layoutSubtreeIfNeeded()
        guard let webView = findWebView(in: contentView) else {
            return XCTFail("WKWebView was not created")
        }

        let configured = webView.underPageBackgroundColor?.usingColorSpace(.sRGB)
        XCTAssertNotNil(configured)
        XCTAssertEqual(configured?.alphaComponent ?? -1, 0.0, accuracy: 0.01)

        controller.close(reason: .statusItemToggle)
    }

    private func findResizeHandle(in view: NSView) -> ResizeHandleView? {
        if let handle = view as? ResizeHandleView { return handle }
        for subview in view.subviews {
            if let handle = findResizeHandle(in: subview) { return handle }
        }
        return nil
    }

    private func findWebView(in view: NSView) -> WKWebView? {
        if let webView = view as? WKWebView { return webView }
        for subview in view.subviews {
            if let webView = findWebView(in: subview) { return webView }
        }
        return nil
    }
}