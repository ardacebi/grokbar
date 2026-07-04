import AppKit
import WebKit

final class PopupChromeContainerView: NSView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        PopupChromeStyle.refreshAppearance(on: self)
    }
}

enum PopupChromeStyle {
    static let cornerRadius: CGFloat = 12
    static let borderWidth: CGFloat = 0.5

    static func apply(to view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.borderWidth = borderWidth
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    }

    static func configureWebViewBackground(_ webView: WKWebView) {
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
    }

    static func refreshAppearance(on view: NSView) {
        view.layer?.backgroundColor = NSColor.clear.cgColor
        if view.layer?.borderWidth ?? 0 > 0 {
            view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        }
    }
}