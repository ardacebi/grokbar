import AppKit
import WebKit

final class MenuBarPopupContentController: NSViewController {
    let presentedController: NSViewController
    private let presentationWrapper = NSView()

    init(presentedController: NSViewController) {
        self.presentedController = presentedController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let clippingView = NSView()
        clippingView.wantsLayer = true
        clippingView.layer?.masksToBounds = true
        clippingView.layer?.backgroundColor = NSColor.clear.cgColor
        view = clippingView

        presentationWrapper.translatesAutoresizingMaskIntoConstraints = false
        clippingView.addSubview(presentationWrapper)

        addChild(presentedController)
        let presentedView = presentedController.view
        presentedView.translatesAutoresizingMaskIntoConstraints = false
        presentationWrapper.addSubview(presentedView)

        NSLayoutConstraint.activate([
            presentationWrapper.leadingAnchor.constraint(equalTo: clippingView.leadingAnchor),
            presentationWrapper.trailingAnchor.constraint(equalTo: clippingView.trailingAnchor),
            presentationWrapper.topAnchor.constraint(equalTo: clippingView.topAnchor),
            presentationWrapper.bottomAnchor.constraint(equalTo: clippingView.bottomAnchor),

            presentedView.leadingAnchor.constraint(equalTo: presentationWrapper.leadingAnchor),
            presentedView.trailingAnchor.constraint(equalTo: presentationWrapper.trailingAnchor),
            presentedView.topAnchor.constraint(equalTo: presentationWrapper.topAnchor),
            presentedView.bottomAnchor.constraint(equalTo: presentationWrapper.bottomAnchor)
        ])
    }

    var presentationContentView: NSView {
        _ = view
        return presentationWrapper
    }

    var presentedView: NSView {
        _ = view
        return presentedController.view
    }
}

final class MenuBarPopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var spaceKeyHandler: (() -> Bool)?
    private var popupContentController: MenuBarPopupContentController?

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
        hasShadow = false
        titlebarAppearsTransparent = true
    }

    var presentationContentView: NSView? {
        popupContentController?.presentationContentView
    }

    func setPresentedContentController(_ controller: NSViewController) {
        let popupContentController = MenuBarPopupContentController(presentedController: controller)
        self.popupContentController = popupContentController
        contentViewController = popupContentController
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
        isShown || isOpening || panel?.isVisible == true
    }

    var isLocalKeyMonitorActive: Bool {
        localKeyMonitor != nil
    }

    private var presentationGeneration = 0
    private var panel: MenuBarPopupPanel?
    private weak var webViewRef: WKWebView?
    private weak var statusItemButton: NSStatusBarButton?

    private var localKeyMonitor: Any?
    private var outsideClickMonitor: Any?
    var retainFocus: Bool = true
    var onWebViewCreate: ((WKWebView) -> Void)?
    var onPopupActiveChanged: ((Bool) -> Void)?

    var presentationWindow: NSWindow? {
        panel
    }

    func configure(hostingController: NSViewController) {
        let popupPanel = MenuBarPopupPanel(contentSize: hostingController.view.frame.size)
        popupPanel.setPresentedContentController(hostingController)
        popupPanel.spaceKeyHandler = { [weak self] in
            self?.handleSpaceKeyEvent() ?? false
        }
        panel = popupPanel
    }

    func setContentSize(_ size: NSSize) {
        if let panel, isPopupActive {
            PopupResizePolicy.applyLiveResizeFrame(
                anchoredFrame(contentSize: size, screen: panel.screen),
                to: panel
            )
        }
    }

    func show(relativeTo button: NSStatusBarButton, contentSize: NSSize) {
        statusItemButton = button
        guard let panel else { return }
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
    }

    func close(reason: PopoverPresentationPolicy.CloseReason) {
        guard isPopupActive else { return }

        guard PopoverPresentationPolicy.shouldClosePopover(for: reason, retainFocus: retainFocus) else {
            return
        }

        closeInvocationCount += 1
        presentationGeneration += 1
        let generation = presentationGeneration
        notifyPopupActiveChanged(false)

        guard let panel else { return }
        isAnimating = true
        isOpening = false
        isShown = false
        let finalFrame = restingFrame(for: panel)
        PopupPresentationAnimation.dismiss(panel, finalFrame: finalFrame) { [weak self] in
            guard let self, generation == self.presentationGeneration else { return }
            self.stopMonitors()
            self.isAnimating = false
            self.isShown = false
        }
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
            webView: webViewRef
        )
    }

    func handleLocalKeyDown(keyCode: UInt16) -> PopoverPresentationPolicy.KeyMonitorAction {
        PopoverPresentationPolicy.keyMonitorAction(
            isPopupActive: isPopupActive,
            keyCode: keyCode
        )
    }

    @discardableResult
    func processMonitoredKeyDown(keyCode: UInt16) -> Bool {
        switch handleLocalKeyDown(keyCode: keyCode) {
        case .passThrough:
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
        guard PopoverPresentationPolicy.shouldInterceptSpaceKey(isPopupActive: isPopupActive) else {
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
            return self.processMonitoredKeyDown(keyCode: event.keyCode) ? event : nil
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
