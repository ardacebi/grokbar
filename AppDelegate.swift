import AppKit
import SwiftUI
import WebKit
import AVFoundation
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    let popupController: PopoverSessionController
    private var contextMenu: NSMenu = NSMenu()
    private weak var webViewRef: WKWebView?
    private let settings = AppSettings()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        self.popupController = PopoverSessionController()
        super.init()
    }

    init(popupController: PopoverSessionController) {
        self.popupController = popupController
        super.init()
    }

    var statusItemButtonForTesting: NSStatusBarButton? {
        statusItem?.button
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        if let button = item.button {
            if let img = loadStatusBarIconFromPNG(size: CGSize(width: 17, height: 16)) {
                img.isTemplate = true
                button.image = img
                button.imageScaling = .scaleProportionallyUpOrDown
                button.imagePosition = .imageOnly
            } else {
                button.image = nil
                button.title = "G"
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popupController.retainFocus = settings.retainPopupFocus
        let hostingController = NSHostingController(
            rootView: PopoverRootView(settings: settings, onWebViewCreate: { [weak self] webView in
                self?.webViewRef = webView
                self?.popupController.registerWebView(webView)
            })
        )
        popupController.configure(hostingController: hostingController)
        popupController.applyBehavior()
        popupController.setContentSize(settings.popupSizePreset.contentSize)
        popupController.onPopupActiveChanged = { [weak self] active in
            guard let self else { return }
            if active {
                StatusItemHighlight.setHighlighted(true, on: self.statusItem?.button)
            } else {
                StatusItemHighlight.clear(on: self.statusItem?.button)
            }
        }

        _ = hostingController.view

        settings.$popupSizePreset
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.settings.isUpdatingFromResizeHandle else { return }
                self.applyPopoverSize(animated: true)
            }
            .store(in: &cancellables)

        settings.$retainPopupFocus
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.popupController.retainFocus = self.settings.retainPopupFocus
                self.popupController.applyBehavior()
                self.buildContextMenu()
            }
            .store(in: &cancellables)

        buildContextMenu()
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    func applicationWillTerminate(_ notification: Notification) {}

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        applyPopoverSize(animated: false)
        popupController.toggle(relativeTo: button, contentSize: settings.popupSizePreset.contentSize)
        if !popupController.isPopupActive {
            StatusItemHighlight.clear(on: button)
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { togglePopover(sender); return }
        switch event.type {
        case .rightMouseUp:
            if let item = statusItem, let button = item.button {
                item.menu = contextMenu
                button.performClick(nil)
                DispatchQueue.main.async { [weak self] in self?.statusItem?.menu = nil }
            }
        default:
            togglePopover(sender)
        }
    }

    private func buildContextMenu() {
        contextMenu.removeAllItems()
        let clear = NSMenuItem(title: "Clear Caches…", action: #selector(clearCaches), keyEquivalent: "")
        clear.target = self
        contextMenu.addItem(clear)

        let retain = NSMenuItem(title: "Retain Popup Focus", action: #selector(toggleRetainPopupFocus), keyEquivalent: "")
        retain.target = self
        retain.state = settings.retainPopupFocus ? .on : .off
        contextMenu.addItem(retain)

        contextMenu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit GrokBar", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        contextMenu.addItem(quit)
    }

    @objc private func toggleRetainPopupFocus() {
        settings.retainPopupFocus.toggle()
    }

    @objc private func clearCaches() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let store = WKWebsiteDataStore.default()
        store.fetchDataRecords(ofTypes: types) { [weak self] records in
            store.removeData(ofTypes: types, for: records) {
                store.httpCookieStore.getAllCookies { cookies in
                    for c in cookies { store.httpCookieStore.delete(c, completionHandler: nil) }
                    DispatchQueue.main.async {
                        if let url = URL(string: "https://grok.com/") {
                            let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
                            self?.webViewRef?.load(req)
                        }
                    }
                }
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applyPopoverSize(animated: Bool) {
        let targetContentSize = settings.popupSizePreset.contentSize
        popupController.setContentSize(targetContentSize)

        guard popupController.isShown,
              let window = popupController.presentationWindow,
              let screen = window.screen else {
            return
        }

        let nextFrame = PopoverPresentationPolicy.panelFrame(
            visibleFrame: screen.visibleFrame,
            contentSize: targetContentSize
        )

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(nextFrame, display: true)
            }
        } else {
            window.setFrame(nextFrame, display: true)
        }
    }

    private func loadStatusBarIconFromPNG(size: CGSize) -> NSImage? {
        if let resURL = Bundle.main.resourceURL {
            let url = resURL.appendingPathComponent("grok-small.png")
            if let img = NSImage(contentsOf: url) {
                img.size = size
                return img
            }
        }
        if let url = Bundle.main.url(forResource: "grok-small", withExtension: "png"), let img = NSImage(contentsOf: url) {
            img.size = size
            return img
        }
        if let execURL = Bundle.main.executableURL {
            let localURL = execURL.deletingLastPathComponent().appendingPathComponent("grok-small.png")
            if let img = NSImage(contentsOf: localURL) { img.size = size; return img }
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let localURL = cwd.appendingPathComponent("grok-small.png")
        if let img = NSImage(contentsOf: localURL) { img.size = size; return img }
        return nil
    }
}

final class FocusableWKWebView: WKWebView {
    override var acceptsFirstResponder: Bool { true }
}

struct WebContainerView: NSViewRepresentable {
    @ObservedObject var settings: AppSettings
    var onCreate: ((WKWebView) -> Void)? = nil

    func makeNSView(context: Context) -> NSView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        if #available(macOS 11.0, *) {
            config.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        if #available(macOS 11.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }
        
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        let webView = FocusableWKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = nil
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        onCreate?(webView)

        let container = NSView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        PopupChromeStyle.apply(to: container)

        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let handle = ResizeHandleView(settings: settings)
        handle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(handle)

        NSLayoutConstraint.activate([
            handle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            handle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            handle.widthAnchor.constraint(equalToConstant: 20),
            handle.heightAnchor.constraint(equalToConstant: 56)
        ])

        if let url = URL(string: "https://grok.com/") {
            let req = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            webView.load(req)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = message
            alert.runModal()
            completionHandler()
        }

        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
            openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
            openPanel.allowedContentTypes = []
            
            if openPanel.runModal() == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }

        @available(macOS 14.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision, WKMediaCaptureType) -> Void) {
            let host = origin.host.lowercased()
            if host.hasSuffix("grok.com") || host == "grok.com" {
                decisionHandler(.grant, type)
            } else {
                decisionHandler(.prompt, type)
            }
        }

        @available(macOS 12.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            let host = origin.host.lowercased()
            if host.hasSuffix("grok.com") || host == "grok.com" {
                decisionHandler(.grant)
            } else {
                decisionHandler(.prompt)
            }
        }
    }
}

final class ResizeHandleView: NSVisualEffectView {
    private let settings: AppSettings

    private var startContinuousIndex: CGFloat?
    private var startWindowFrame: NSRect?

    init(settings: AppSettings) {
        self.settings = settings
        super.init(frame: .zero)

        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 10
        alphaValue = 0.85

        // Three horizontal lines as a drag indicator (like a grip)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.distribution = .equalSpacing
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for _ in 0..<3 {
            let line = NSView()
            line.wantsLayer = true
            line.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.5).cgColor
            line.layer?.cornerRadius = 1.5
            line.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(line)
            NSLayoutConstraint.activate([
                line.widthAnchor.constraint(equalToConstant: 10),
                line.heightAnchor.constraint(equalToConstant: 3)
            ])
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1.0
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 0.85
        }
    }

    @objc private func handlePan(_ recognizer: NSPanGestureRecognizer) {
        guard let window else { return }

        let presets = PopupSizePreset.allCases.map(\.contentSize)
        guard presets.count == 4, let screen = window.screen else { return }

        let translation = recognizer.translation(in: self)
        let scalar = -translation.y
        let pointsPerPresetStep: CGFloat = 80

        switch recognizer.state {
        case .began:
            startContinuousIndex = CGFloat(settings.popupSizePreset.index)
            startWindowFrame = window.frame

        case .changed:
            guard let startIndex = startContinuousIndex else { return }

            let clamped = max(0, min(CGFloat(presets.count - 1), startIndex + (scalar / pointsPerPresetStep)))
            let lower = Int(floor(clamped))
            let upper = Int(ceil(clamped))
            let t = clamped - CGFloat(lower)
            let a = presets[lower]
            let b = presets[upper]
            let interpolated = NSSize(
                width: a.width + (b.width - a.width) * t,
                height: a.height + (b.height - a.height) * t
            )
            let nextFrame = PopoverPresentationPolicy.panelFrame(
                visibleFrame: screen.visibleFrame,
                contentSize: interpolated
            )

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            window.setFrame(nextFrame, display: true)
            window.contentView?.layoutSubtreeIfNeeded()
            CATransaction.commit()

        case .ended, .cancelled, .failed:
            defer {
                startContinuousIndex = nil
                startWindowFrame = nil
            }

            guard let startIndex = startContinuousIndex else { return }

            let rawIndex = startIndex + (scalar / pointsPerPresetStep)
            let snapped = Int(max(0, min(CGFloat(presets.count - 1), rawIndex)).rounded())
            let preset = PopupSizePreset.from(index: snapped)
            let finalFrame = PopoverPresentationPolicy.panelFrame(
                visibleFrame: screen.visibleFrame,
                contentSize: preset.contentSize
            )

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.16
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(finalFrame, display: true)
            }, completionHandler: {
                self.settings.updatePresetFromResizeHandle(preset)
            })

        default:
            break
        }
    }
}
