import AppKit

enum PopupChromeStyle {
    static let cornerRadius: CGFloat = 12
    static let borderWidth: CGFloat = 0.5

    static func apply(to view: NSView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = borderWidth
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    }
}