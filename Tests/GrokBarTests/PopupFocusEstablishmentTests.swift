import XCTest
@testable import GrokBar

final class PopupFocusEstablishmentTests: XCTestCase {
    func testShouldActivateOnMacOS27() {
        XCTAssertTrue(PopupFocusEstablishment.shouldActivateApplication(osMajorVersion: 27))
        XCTAssertFalse(PopupFocusEstablishment.shouldActivateApplication(osMajorVersion: 14))
    }

    func testEstablishReturnsFalseWithoutWindow() {
        XCTAssertFalse(
            PopupFocusEstablishment.establish(
                window: nil,
                webView: nil,
                osMajorVersion: 27
            )
        )
    }
}