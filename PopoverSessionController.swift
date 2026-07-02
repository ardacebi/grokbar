import AppKit
import WebKit

final class MenuBarPopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var spaceKeyHandler: (() -> Bool)?

    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titlebarAppearsTransparent = true
    }

    func applyContentChrome() {
        guard let view = contentViewController?.view else { return }
        PopupChromeStyle.apply(to: view)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           event.keyCode == PopoverPresentationPolicy.spaceKeyCode,
           spaceKeyHandler?() == true {
            return
        }

        if event.type == .keyDown,
           let responder = firstResponder,
           responder !== self {
            responder.keyDown(with: event)
            return
        }
        super.sendEvent(event)
    }
}

final class PopoverSessionController: NSObject {
    private(set) var isShown = false
    private(set) var isOpening = false
    private(set) var isAnimating = false
    private(set) var closeInvocationCount = 0

    var isPopupActive: Bool {
        isShown || isOpening || panel?.isVisible == true || popover?.isShown == true
    }

    var isLocalKeyMonitorActive: Bool {
        localKeyMonitor != nil
    }

    private let osMajorVersion: Int
    private var presentationGeneration = 0
    private var panel: MenuBarPopupPanel?
    private var popover: NSPopover?
    private var hostingController: NSViewController?
    private weak var webViewRef: WKWebView?
    private weak var statusItemButton: NSStatusBarButton?

    private var localKeyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var pendingCloseReason: PopoverPresentationPolicy.CloseReason = .systemRequest

    var retainFocus: Bool = true
    var onWebViewCreate: ((WKWebView) -> Void)?
    var onPopupActiveChanged: ((Bool) -> Void)?

    var presentationWindow: NSWindow? {
        if PopoverPresentationPolicy.shouldUseAnchoredPanel(osMajorVersion: osMajorVersion) {
            return panel
        }
        return popover?.contentViewController?.view.window
    }

    init(osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) {
        self.osMajorVersion = osMajorVersion
        super.init()
    }

    func configure(hostingController: NSViewController) {
        self.hostingController = hostingController

        if PopoverPresentationPolicy.shouldUseAnchoredPanel(osMajorVersion: osMajorVersion) {
            let popupPanel = MenuBarPopupPanel(contentSize: hostingController.view.frame.size)
            popupPanel.contentViewController = hostingController
            popupPanel.spaceKeyHandler = { [weak self] in
                self?.handleSpaceKeyEvent() ?? false
            }
            panel = popupPanel
        } else {
            let legacyPopover = NSPopover()
            legacyPopover.delegate = self
            legacyPopover.animates = true
            legacyPopover.contentViewController = hostingController
            popover = legacyPopover
        }
    }

    func applyBehavior() {
        popover?.behavior = PopoverPresentationPolicy.popoverBehavior(
            retainFocus: retainFocus,
            osMajorVersion: osMajorVersion
        )
    }

    func setContentSize(_ size: NSSize) {
        popover?.contentSize = size
        if let panel, isPopupActive {
            panel.setFrame(anchoredFrame(contentSize: size, screen: panel.screen), display: true)
        }
    }

    func show(relativeTo button: NSStatusBarButton, contentSize: NSSize) {
        statusItemButton = button
        pendingCloseReason = .systemRequest
        applyBehavior()

        if let panel {
            panel.contentViewController = hostingController
            let finalFrame = anchoredFrame(for: button, contentSize: contentSize)

            presentationGeneration += 1
            let generation = presentationGeneration
            isOpening = true
            isAnimating = true
            isShown = false
            startMonitors()

            if panel.isVisible {
                notifyPopupActiveChanged(true)
            }

            PopupPresentationAnimation.present(
                panel,
                finalFrame: finalFrame,
                onPresented: { [weak self] in
                    self?.establishTypingFocus()
                },
                completion: { [weak self] in
                    guard let self, generation == self.presentationGeneration else { return }
                    self.isAnimating = false
                    self.isOpening = false
                    self.isShown = true
                    self.notifyPopupActiveChanged(true)
                    self.establishTypingFocus()
                }
            )
            return
        }

        guard let popover else { return }
        popover.contentSize = contentSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isShown = popover.isShown
        notifyPopupActiveChanged(true)
        startMonitors()
        establishTypingFocus()
    }

    func close(reason: PopoverPresentationPolicy.CloseReason) {
        guard isPopupActive else { return }

        pendingCloseReason = reason

        guard PopoverPresentationPolicy.shouldClosePopover(for: reason, retainFocus: retainFocus) else {
            pendingCloseReason = .systemRequest
            return
        }

        closeInvocationCount += 1
        presentationGeneration += 1
        let generation = presentationGeneration
        notifyPopupActiveChanged(false)

        if let panel {
            isAnimating = true
            isOpening = false
            isShown = false
            let finalFrame = restingFrame(for: panel)
            PopupPresentationAnimation.dismiss(panel, finalFrame: finalFrame) { [weak self] in
                guard let self, generation == self.presentationGeneration else { return }
                self.stopMonitors()
                self.isAnimating = false
                self.isShown = false
                self.pendingCloseReason = .systemRequest
            }
            return
        } else if let popover {
            stopMonitors()
            popover.performClose(nil)
            if popover.isShown {
                popover.close()
            }
        }

        stopMonitors()
        isShown = false
        pendingCloseReason = .systemRequest
        notifyPopupActiveChanged(false)
    }

    func toggle(relativeTo button: NSStatusBarButton, contentSize: NSSize) {
        statusItemButton = button

        if isAnimating && !isOpening {
            show(relativeTo: button, contentSize: contentSize)
            return
        }

        if isOpening || isShown {
            close(reason: .statusItemToggle)
            return
        }

        show(relativeTo: button, contentSize: contentSize)
    }

    private func restingFrame(for panel: MenuBarPopupPanel) -> NSRect {
        let contentSize = panel.frame.size
        if let button = statusItemButton {
            return anchoredFrame(for: button, contentSize: contentSize)
        }
        return anchoredFrame(contentSize: contentSize, screen: panel.screen)
    }

    func establishTypingFocus() {
        PopupFocusEstablishment.establish(
            window: presentationWindow,
            webView: webViewRef,
            osMajorVersion: osMajorVersion
        )
    }

    func handleLocalKeyDown(keyCode: UInt16, eventType: NSEvent.EventType) -> PopoverPresentationPolicy.KeyMonitorAction {
        PopoverPresentationPolicy.keyMonitorAction(
            isPopupActive: isPopupActive,
            keyCode: keyCode,
            eventType: eventType,
            osMajorVersion: osMajorVersion
        )
    }

    @discardableResult
    func processMonitoredKeyDown(keyCode: UInt16, eventType: NSEvent.EventType) -> Bool {
        switch handleLocalKeyDown(keyCode: keyCode, eventType: eventType) {
        case .passThrough:
            establishTypingFocus()
            return true
        case .consumeAndInsertSpace:
            _ = handleSpaceKeyEvent()
            return false
        case .close(let reason):
            close(reason: reason)
            return false
        }
    }

    @discardableResult
    func handleSpaceKeyEvent() -> Bool {
        guard PopoverPresentationPolicy.shouldInterceptSpaceKey(
            isPopupActive: isPopupActive,
            osMajorVersion: osMajorVersion
        ) else {
            return false
        }

        establishTypingFocus()
        injectSpaceIntoWebView()
        return true
    }

    func injectSpaceIntoWebView() {
        webViewRef?.evaluateJavaScript(PopoverPresentationPolicy.spaceInsertionScript, completionHandler: nil)
    }

    func registerWebView(_ webView: WKWebView) {
        webViewRef = webView
        onWebViewCreate?(webView)
    }

    func anchoredFrame(for button: NSStatusBarButton, contentSize: NSSize) -> NSRect {
        anchoredFrame(contentSize: contentSize, screen: button.window?.screen)
    }

    private func notifyPopupActiveChanged(_ active: Bool) {
        onPopupActiveChanged?(active)
    }

    func anchoredFrame(contentSize: NSSize, screen: NSScreen?) -> NSRect {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else {
            return NSRect(origin: .zero, size: contentSize)
        }
        return PopoverPresentationPolicy.panelFrame(
            visibleFrame: targetScreen.visibleFrame,
            contentSize: contentSize
        )
    }

    private func startMonitors() {
        stopMonitors()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.processMonitoredKeyDown(keyCode: event.keyCode, eventType: event.type) ? event : nil
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.isShown, let window = self.presentationWindow else { return }

            let screenLocation = NSEvent.mouseLocation
            let statusItemFrame = self.statusItemButton?.window?.convertToScreen(
                self.statusItemButton?.convert(self.statusItemButton?.bounds ?? .zero, to: nil) ?? .zero
            )

            if PopoverPresentationPolicy.shouldDismissForMouseEvent(
                type: event.type,
                screenLocation: screenLocation,
                popoverFrame: window.frame,
                statusItemFrame: statusItemFrame,
                retainFocus: self.retainFocus
            ) {
                self.close(reason: .outsideClick)
            }
        }
    }

    private func stopMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }
}

extension PopoverSessionController: NSPopoverDelegate {
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        PopoverPresentationPolicy.shouldClosePopover(for: pendingCloseReason, retainFocus: retainFocus)
    }

    func popoverDidShow(_ notification: Notification) {
        isShown = true
        notifyPopupActiveChanged(true)
        establishTypingFocus()
    }

    func popoverDidClose(_ notification: Notification) {
        isShown = false
        notifyPopupActiveChanged(false)
        stopMonitors()
    }
}