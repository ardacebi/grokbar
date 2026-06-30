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

    enum KeyMonitorAction: Equatable {
        case passThrough
        case consumeAndInsertSpace
        case close(CloseReason)
    }

    static func isMacOS27OrLater(
        osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> Bool {
        osMajorVersion >= 27
    }

    static func popoverBehavior(
        retainFocus: Bool,
        osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> NSPopover.Behavior {
        if isMacOS27OrLater(osMajorVersion: osMajorVersion) || retainFocus {
            return .applicationDefined
        }
        return .transient
    }

    static func shouldActivateApplicationOnShow(
        osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> Bool {
        isMacOS27OrLater(osMajorVersion: osMajorVersion)
    }

    static func shouldUseAnchoredPanel(
        osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    ) -> Bool {
        isMacOS27OrLater(osMajorVersion: osMajorVersion)
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

    static func keyMonitorAction(
        isShown: Bool,
        keyCode: UInt16,
        eventType: NSEvent.EventType,
        osMajorVersion: Int
    ) -> KeyMonitorAction {
        guard isShown else { return .passThrough }

        if let closeReason = closeReason(forKeyCode: keyCode) {
            return .close(closeReason)
        }

        if keyCode == spaceKeyCode && isMacOS27OrLater(osMajorVersion: osMajorVersion) {
            return .consumeAndInsertSpace
        }

        if isTypingKeyCode(keyCode) {
            return .passThrough
        }

        return .passThrough
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

    static func panelFrame(
        anchor: NSRect,
        contentSize: NSSize
    ) -> NSRect {
        NSRect(
            x: anchor.midX - contentSize.width / 2,
            y: anchor.minY - contentSize.height,
            width: contentSize.width,
            height: contentSize.height
        )
    }

    static let spaceInsertionScript = """
    (function() {
      const el = document.activeElement;
      if (!el) { return false; }
      if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
        const start = el.selectionStart ?? el.value.length;
        const end = el.selectionEnd ?? el.value.length;
        el.value = el.value.slice(0, start) + ' ' + el.value.slice(end);
        el.selectionStart = el.selectionEnd = start + 1;
        el.dispatchEvent(new Event('input', { bubbles: true }));
        return true;
      }
      if (el.isContentEditable) {
        document.execCommand('insertText', false, ' ');
        return true;
      }
      return false;
    })();
    """
}