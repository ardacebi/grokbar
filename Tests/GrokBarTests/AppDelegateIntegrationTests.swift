import XCTest
@testable import GrokBar

final class AppDelegateIntegrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

    func testTogglePopoverOpensAndClosesThroughAppDelegate() throws {
        let controller = PopoverSessionController(osMajorVersion: 27)
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)
        XCTAssertTrue(controller.isPopupActive)
        XCTAssertTrue(controller.presentationWindow is MenuBarPopupPanel)

        let closeExpectation = expectation(description: "close animation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            delegate.togglePopover(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                XCTAssertFalse(controller.isPopupActive)
                closeExpectation.fulfill()
            }
        }
        wait(for: [closeExpectation], timeout: 3.0)
    }

    func testApplyPopoverSizeUsesPopupControllerWindow() throws {
        let controller = PopoverSessionController(osMajorVersion: 27)
        let delegate = AppDelegate(popupController: controller)
        delegate.applicationDidFinishLaunching(Notification(name: Notification.Name("testLaunch")))

        guard delegate.statusItemButtonForTesting != nil else {
            throw XCTSkip("Status item unavailable in this test environment")
        }

        delegate.togglePopover(nil)

        let openExpectation = expectation(description: "open")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            delegate.applyPopoverSize(animated: false)
            XCTAssertNotNil(controller.presentationWindow)
            openExpectation.fulfill()
        }
        wait(for: [openExpectation], timeout: 2.0)
    }
}