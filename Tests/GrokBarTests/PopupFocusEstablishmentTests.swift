import XCTest
import WebKit
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

    func testEstablishIsNoOpWhenWebViewAlreadyHasFocus() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let webView = WKWebView(frame: window.contentView?.bounds ?? .zero, configuration: WKWebViewConfiguration())
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        XCTAssertTrue(window.makeFirstResponder(webView))

        _ = PopupFocusEstablishment.establish(window: window, webView: webView)
        XCTAssertIdentical(window.firstResponder, webView)
    }
}
