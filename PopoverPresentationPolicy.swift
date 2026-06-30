import AppKit

enum PopoverPresentationPolicy {
    static let spaceKeyCode: UInt16 = 49

    static var isMacOS27OrLater: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }

    static func popoverBehavior(retainFocus: Bool) -> NSPopover.Behavior {
        if isMacOS27OrLater || retainFocus {
            return .applicationDefined
        }
        return .transient
    }

    static func shouldActivateApplicationOnShow() -> Bool {
        isMacOS27OrLater
    }

    static func shouldDismissForKeyEvent(type: NSEvent.EventType, keyCode: UInt16) -> Bool {
        guard type == .keyDown || type == .keyUp else { return false }
        return !isTypingKeyCode(keyCode)
    }

    static func isTypingKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case spaceKeyCode,
             0...46, 48...53,
             96...111,
             123...126:
            return true
        default:
            return false
        }
    }

    static func shouldDismissForMouseEvent(
        type: NSEvent.EventType,
        screenLocation: NSPoint,
        popoverFrame: NSRect,
        statusItemFrame: NSRect?
    ) -> Bool {
        guard type == .leftMouseDown || type == .rightMouseDown else { return false }
        if popoverFrame.contains(screenLocation) { return false }
        if let statusItemFrame, statusItemFrame.contains(screenLocation) { return false }
        return true
    }
}