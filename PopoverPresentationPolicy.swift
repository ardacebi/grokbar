import AppKit

enum PopoverPresentationPolicy {
    static let spaceKeyCode: UInt16 = 49
    static let escapeKeyCode: UInt16 = 53

    enum CloseReason: Equatable {
        case statusItemToggle
        case outsideClick
        case escapeKey
        case systemRequest
    }

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

    static func shouldClosePopover(for reason: CloseReason) -> Bool {
        switch reason {
        case .statusItemToggle, .outsideClick, .escapeKey:
            return true
        case .systemRequest:
            return false
        }
    }

    static func closeReason(forKeyCode keyCode: UInt16) -> CloseReason? {
        keyCode == escapeKeyCode ? .escapeKey : nil
    }

    static func shouldDismissForKeyEvent(type: NSEvent.EventType, keyCode: UInt16) -> Bool {
        guard type == .keyDown || type == .keyUp else { return false }
        if closeReason(forKeyCode: keyCode) != nil { return true }
        return !isTypingKeyCode(keyCode)
    }

    static func isTypingKeyCode(_ keyCode: UInt16) -> Bool {
        if keyCode == escapeKeyCode { return false }
        switch keyCode {
        case spaceKeyCode,
             0...46, 48...52,
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