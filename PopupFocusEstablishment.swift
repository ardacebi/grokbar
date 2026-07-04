import AppKit
import WebKit

enum PopupFocusEstablishment {
    @discardableResult
    static func establish(
        window: NSWindow?,
        webView: WKWebView?
    ) -> Bool {
        guard let window else { return false }

        if let webView, window.firstResponder === webView {
            if window.isKeyWindow { return true }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return window.isKeyWindow
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        if let webView {
            return window.makeFirstResponder(webView)
        }

        return window.isKeyWindow
    }
}
