import AppKit
import WebKit

final class MenuBarPopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

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

    var isPopupActive: Bool { isShown || isOpening }

    private let osMajorVersion: Int
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
            popupPanel.applyContentChrome()
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
            var frame = panel.frame
            frame.size = size
            frame.origin.y = frame.maxY - size.height
            panel.setFrame(frame, display: true)
        }
    }

    func show(relativeTo button: NSStatusBarButton, contentSize: NSSize) {
        statusItemButton = button
        pendingCloseReason = .systemRequest
        applyBehavior()

        if let panel {
            panel.contentViewController = hostingController
            panel.applyContentChrome()
            let finalFrame = anchoredFrame(for: button, contentSize: contentSize)

            isOpening = true
            isAnimating = true
            startMonitors()

            PopupPresentationAnimation.present(
                panel,
                finalFrame: finalFrame,
                onPresented: { [weak self] in
                    self?.establishTypingFocus()
                },
                completion: { [weak self] in
                    guard let self else { return }
                    self.isAnimating = false
                    self.isOpening = false
                    self.isShown = true
                    self.establishTypingFocus()
                }
            )
            return
        }

        guard let popover else { return }
        popover.contentSize = contentSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isShown = popover.isShown
        startMonitors()
        establishTypingFocus()
    }

    func close(reason: PopoverPresentationPolicy.CloseReason) {
        guard isPopupActive else { return }

        stopMonitors()
        pendingCloseReason = reason

        guard PopoverPresentationPolicy.shouldClosePopover(for: reason) else {
            pendingCloseReason = .systemRequest
            if isOpening {
                isOpening = false
            }
            return
        }

        if let panel {
            isAnimating = true
            isOpening = false
            PopupPresentationAnimation.dismiss(panel) { [weak self] in
                guard let self else { return }
                self.isAnimating = false
                self.isShown = false
                self.pendingCloseReason = .systemRequest
            }
            return
        } else if let popover {
            popover.performClose(nil)
            if popover.isShown {
                popover.close()
            }
        }

        isShown = false
        pendingCloseReason = .systemRequest
    }

    func toggle(relativeTo button: NSStatusBarButton, contentSize: NSSize) {
        guard !isAnimating else { return }

        if isPopupActive {
            close(reason: .statusItemToggle)
        } else {
            show(relativeTo: button, contentSize: contentSize)
        }
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

    func injectSpaceIntoWebView() {
        webViewRef?.evaluateJavaScript(PopoverPresentationPolicy.spaceInsertionScript, completionHandler: nil)
    }

    func registerWebView(_ webView: WKWebView) {
        webViewRef = webView
        onWebViewCreate?(webView)
    }

    func anchoredFrame(for button: NSStatusBarButton, contentSize: NSSize) -> NSRect {
        guard let buttonWindow = button.window else {
            return NSRect(origin: .zero, size: contentSize)
        }
        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenAnchor = buttonWindow.convertToScreen(buttonFrame)
        return PopoverPresentationPolicy.panelFrame(anchor: screenAnchor, contentSize: contentSize)
    }

    private func startMonitors() {
        stopMonitors()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            switch self.handleLocalKeyDown(keyCode: event.keyCode, eventType: event.type) {
            case .passThrough:
                self.establishTypingFocus()
                return event
            case .consumeAndInsertSpace:
                self.establishTypingFocus()
                self.injectSpaceIntoWebView()
                return nil
            case .close(let reason):
                self.close(reason: reason)
                return nil
            }
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
                statusItemFrame: statusItemFrame
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
        PopoverPresentationPolicy.shouldClosePopover(for: pendingCloseReason)
    }

    func popoverDidShow(_ notification: Notification) {
        isShown = true
        establishTypingFocus()
    }

    func popoverDidClose(_ notification: Notification) {
        isShown = false
        stopMonitors()
    }
}