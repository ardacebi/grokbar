import AppKit
import WebKit

enum PopupFocusEstablishment {
    static func shouldActivateApplication(osMajorVersion: Int) -> Bool {
        PopoverPresentationPolicy.shouldActivateApplicationOnShow(osMajorVersion: osMajorVersion)
    }

    @discardableResult
    static func establish(
        window: NSWindow?,
        webView: WKWebView?,
        osMajorVersion: Int
    ) -> Bool {
        guard let window else { return false }

        if shouldActivateApplication(osMajorVersion: osMajorVersion) {
            NSApp.activate(ignoringOtherApps: true)
        }

        window.makeKeyAndOrderFront(nil)

        if let webView {
            return window.makeFirstResponder(webView)
        }

        return window.isKeyWindow
    }
}