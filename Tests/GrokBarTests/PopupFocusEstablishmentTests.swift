import XCTest
@testable import GrokBar

final class PopupFocusEstablishmentTests: XCTestCase {
    func testEstablishReturnsFalseWithoutWindow() {
        XCTAssertFalse(
            PopupFocusEstablishment.establish(
                window: nil,
                webView: nil
            )
        )
    }
}
