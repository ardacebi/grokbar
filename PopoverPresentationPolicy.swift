import AppKit

enum PopoverPresentationPolicy {
    static let spaceKeyCode: UInt16 = 49
    static let escapeKeyCode: UInt16 = 53

    enum CloseReason: Equatable {
        case statusItemToggle
        case outsideClick
        case escapeKey
    }

    enum KeyMonitorAction: Equatable {
        case passThrough
        case consumeAndInsertSpace
        case close(CloseReason)
    }

    static func shouldClosePopover(for reason: CloseReason, retainFocus: Bool = false) -> Bool {
        switch reason {
        case .statusItemToggle, .escapeKey:
            return true
        case .outsideClick:
            return !retainFocus
        }
    }

    static func closeReason(forKeyCode keyCode: UInt16) -> CloseReason? {
        keyCode == escapeKeyCode ? .escapeKey : nil
    }

    static func shouldInterceptSpaceKey(isPopupActive: Bool) -> Bool {
        isPopupActive
    }

    static func keyMonitorAction(
        isPopupActive: Bool,
        keyCode: UInt16
    ) -> KeyMonitorAction {
        guard isPopupActive else { return .passThrough }

        if keyCode == spaceKeyCode && shouldInterceptSpaceKey(isPopupActive: true) {
            return .consumeAndInsertSpace
        }

        if let closeReason = closeReason(forKeyCode: keyCode) {
            return .close(closeReason)
        }

        return .passThrough
    }

    static func shouldDismissForMouseEvent(
        type: NSEvent.EventType,
        screenLocation: NSPoint,
        popoverFrame: NSRect,
        statusItemFrame: NSRect?,
        retainFocus: Bool = false
    ) -> Bool {
        guard !retainFocus else { return false }
        guard type == .leftMouseDown || type == .rightMouseDown else { return false }
        if popoverFrame.contains(screenLocation) { return false }
        if let statusItemFrame, statusItemFrame.contains(screenLocation) { return false }
        return true
    }

    static let screenMargin: CGFloat = 8

    static func panelFrame(
        visibleFrame: NSRect,
        contentSize: NSSize,
        margin: CGFloat = screenMargin
    ) -> NSRect {
        NSRect(
            x: visibleFrame.maxX - contentSize.width - margin,
            y: visibleFrame.maxY - contentSize.height - margin,
            width: contentSize.width,
            height: contentSize.height
        )
    }

    static let spaceInsertionScript = """
    (function() {
      function insertSpace(el) {
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
          el.focus();
          document.execCommand('insertText', false, ' ');
          el.dispatchEvent(new Event('input', { bubbles: true }));
          return true;
        }
        return false;
      }

      if (insertSpace(document.activeElement)) { return true; }

      const selectors = [
        'textarea',
        'input[type="text"]',
        'input:not([type])',
        '[contenteditable="true"]',
        '[role="textbox"]'
      ];

      for (const selector of selectors) {
        for (const candidate of document.querySelectorAll(selector)) {
          if (candidate.offsetParent === null) { continue; }
          if (insertSpace(candidate)) {
            candidate.focus();
            return true;
          }
        }
      }

      return false;
    })();
    """
}
