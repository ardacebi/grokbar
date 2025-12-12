import AppKit
import SwiftUI
import WebKit
import AVFoundation
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover = NSPopover()
    private var contextMenu: NSMenu = NSMenu()
    private weak var webViewRef: WKWebView?
    private let settings = AppSettings()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
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

        applyPopoverBehavior()
        popover.animates = true
        popover.contentSize = settings.popupSizePreset.contentSize
        popover.contentViewController = NSHostingController(rootView: PopoverRootView(settings: settings, onWebViewCreate: { [weak self] webView in
            self?.webViewRef = webView
        }))

        _ = popover.contentViewController?.view

        settings.$popupSizePreset
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyPopoverSize(animated: true)
            }
            .store(in: &cancellables)

        settings.$retainPopupFocus
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyPopoverBehavior()
                self?.buildContextMenu()
            }
            .store(in: &cancellables)

        configureCookiePersistence()

    buildContextMenu()

        AVCaptureDevice.requestAccess(for: .audio) { granted in

        }
    }

    func applicationWillTerminate(_ notification: Notification) {}

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else if let button = statusItem.button {
            applyPopoverSize(animated: false)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { togglePopover(sender); return }
        switch event.type {
        case .rightMouseUp:
            if let button = statusItem.button {
                statusItem.menu = contextMenu
                button.performClick(nil)
                DispatchQueue.main.async { [weak self] in self?.statusItem.menu = nil }
            }
        default:
            togglePopover(sender)
        }
    }

    private func closePopover(sender: Any?) {
        popover.performClose(sender)
    }

    private func configureCookiePersistence() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                var props = cookie.properties ?? [:]
                props[.discard] = false
            }
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

    private func applyPopoverBehavior() {
        if settings.retainPopupFocus {
            popover.behavior = .applicationDefined
        } else {
            popover.behavior = .transient
        }
    }

    private func applyPopoverSize(animated: Bool) {
        let targetContentSize = settings.popupSizePreset.contentSize
        popover.contentSize = targetContentSize

        guard popover.isShown,
              let window = popover.contentViewController?.view.window else {
            return
        }

        let currentFrame = window.frame
        let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetContentSize)).size

        var nextFrame = currentFrame
        nextFrame.size = targetFrameSize
        nextFrame.origin.x = currentFrame.minX
        nextFrame.origin.y = currentFrame.maxY - targetFrameSize.height

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

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = nil
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        onCreate?(webView)

        let container = NSView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false

        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Blur overlay for resize feedback
        let blurOverlay = NSVisualEffectView()
        blurOverlay.material = .fullScreenUI
        blurOverlay.blendingMode = .withinWindow
        blurOverlay.state = .active
        blurOverlay.alphaValue = 0
        blurOverlay.isHidden = true
        blurOverlay.translatesAutoresizingMaskIntoConstraints = false
        blurOverlay.identifier = NSUserInterfaceItemIdentifier("resizeBlurOverlay")
        container.addSubview(blurOverlay)

        NSLayoutConstraint.activate([
            blurOverlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blurOverlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            blurOverlay.topAnchor.constraint(equalTo: container.topAnchor),
            blurOverlay.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Snapshot image view to freeze content during resize
        let snapshotView = NSImageView()
        snapshotView.imageScaling = .scaleProportionallyUpOrDown
        snapshotView.alphaValue = 0
        snapshotView.isHidden = true
        snapshotView.translatesAutoresizingMaskIntoConstraints = false
        snapshotView.identifier = NSUserInterfaceItemIdentifier("resizeSnapshotView")
        container.addSubview(snapshotView)

        NSLayoutConstraint.activate([
            snapshotView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            snapshotView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            snapshotView.topAnchor.constraint(equalTo: container.topAnchor),
            snapshotView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
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
        guard let window = self.window else { return }

        let presets = PopupSizePreset.allCases.map { $0.contentSize }
        guard presets.count == 4 else { return }

        let translation = recognizer.translation(in: self)
        // Dragging DOWN (positive y) should make popup LARGER, so we negate y
        let scalar = -translation.y

        // Drag farther -> proportionally larger/smaller, smoothly.
        let pointsPerPresetStep: CGFloat = 80

        // Find the overlay views in the content view
        let blurOverlay = window.contentView?.subviews.first(where: {
            $0.identifier == NSUserInterfaceItemIdentifier("resizeBlurOverlay")
        }) as? NSVisualEffectView

        let snapshotView = window.contentView?.subviews.first(where: {
            $0.identifier == NSUserInterfaceItemIdentifier("resizeSnapshotView")
        }) as? NSImageView

        // Find the webview to hide during resize
        let webView = window.contentView?.subviews.first(where: { $0 is WKWebView }) as? WKWebView

        switch recognizer.state {
        case .began:
            startContinuousIndex = CGFloat(settings.popupSizePreset.index)
            startWindowFrame = window.frame

            // Take a snapshot of the webview and show it
            if let webView = webView {
                let bitmapRep = webView.bitmapImageRepForCachingDisplay(in: webView.bounds)
                if let bitmapRep = bitmapRep {
                    webView.cacheDisplay(in: webView.bounds, to: bitmapRep)
                    let image = NSImage(size: webView.bounds.size)
                    image.addRepresentation(bitmapRep)
                    snapshotView?.image = image
                }
            }

            // Show snapshot and blur, hide webview for smooth resize
            snapshotView?.isHidden = false
            blurOverlay?.isHidden = false
            snapshotView?.alphaValue = 1
            blurOverlay?.alphaValue = 0.5
            webView?.alphaValue = 0

        case .changed:
            guard let startIndex = startContinuousIndex,
                  let startFrame = startWindowFrame else { return }

            let rawIndex = startIndex + (scalar / pointsPerPresetStep)
            let clamped = max(0, min(CGFloat(presets.count - 1), rawIndex))

            let lower = Int(floor(clamped))
            let upper = Int(ceil(clamped))
            let t = clamped - CGFloat(lower)

            let a = presets[lower]
            let b = presets[upper]
            let interpolated = NSSize(
                width: a.width + (b.width - a.width) * t,
                height: a.height + (b.height - a.height) * t
            )

            let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: interpolated)).size
            var nextFrame = startFrame
            nextFrame.size = targetFrameSize
            nextFrame.origin.x = startFrame.minX
            nextFrame.origin.y = startFrame.maxY - targetFrameSize.height

            // Direct frame update for smooth real-time resizing
            window.setFrame(nextFrame, display: false)

        case .ended, .cancelled, .failed:
            defer {
                startContinuousIndex = nil
                startWindowFrame = nil
            }

            guard let startIndex = startContinuousIndex,
                  let startFrame = startWindowFrame else { return }

            let rawIndex = startIndex + (scalar / pointsPerPresetStep)
            let snapped = Int((max(0, min(CGFloat(presets.count - 1), rawIndex))).rounded())
            let preset = PopupSizePreset.from(index: snapped)

            // Animate to final snapped size
            let finalSize = preset.contentSize
            let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: finalSize)).size
            var finalFrame = startFrame
            finalFrame.size = targetFrameSize
            finalFrame.origin.x = startFrame.minX
            finalFrame.origin.y = startFrame.maxY - targetFrameSize.height

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(finalFrame, display: false)
            }, completionHandler: {
                // Restore webview and hide snapshot/blur
                webView?.alphaValue = 1
                snapshotView?.alphaValue = 0
                blurOverlay?.alphaValue = 0
                snapshotView?.isHidden = true
                blurOverlay?.isHidden = true
                snapshotView?.image = nil

                if preset != self.settings.popupSizePreset {
                    self.settings.popupSizePreset = preset
                }
            })

        default:
            break
        }
    }
}

extension AppDelegate {
    private func renderStatusBarIconFromSVG(size: CGSize, completion: @escaping (NSImage?) -> Void) {
        let svgPaths = [
            "m132.37 210.4 110.82 -81.9c5.43 -4 13.2 -2.44 15.78 3.8 13.63 32.88 7.54 72.41 -19.57 99.55 -27.1 27.14 -64.82 33.1 -99.3 19.54l-37.65 17.45c54.01 36.97 119.6 27.82 160.59 -13.24 32.51 -32.55 42.58 -76.92 33.17 -116.93l0.08 0.09c-13.65 -58.78 3.36 -82.27 38.2 -130.31q1.23 -1.7 2.47 -3.45l-45.85 45.9v-0.14L132.34 210.44",
            "M109.5 230.31c-38.77 -37.07 -32.08 -94.46 1 -127.55 24.46 -24.49 64.54 -34.48 99.52 -19.79L247.6 65.6c-6.77 -4.9 -15.45 -10.17 -25.4 -13.87A124.65 124.65 0 0 0 86.75 79.01c-35.19 35.23 -46.25 89.4 -27.25 135.61 14.2 34.54 -9.07 58.98 -32.51 83.64 -8.3 8.74 -16.64 17.49 -23.35 26.74l105.83 -94.66"
        ]

        let svg = """
        <svg viewBox=\"0 0 800 800\" xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" height=\"100%\" preserveAspectRatio=\"xMidYMid slice\">
            <g fill=\"black\">
                <path d=\"\(svgPaths[0])\" />
                <path d=\"\(svgPaths[1])\" />
            </g>
        </svg>
        """

        let html = """
        <html><head><meta name=\"color-scheme\" content=\"light dark\"></head>
        <body style=\"margin:0;background:transparent;\">\(svg)</body></html>
        """

    let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
    let pixelSize = CGSize(width: size.width * 2, height: size.height * 2)
    let webView = WKWebView(frame: CGRect(origin: .zero, size: pixelSize), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        class Loader: NSObject, WKNavigationDelegate {
            let size: CGSize
            let pixelSize: CGSize
            let completion: (NSImage?) -> Void
            init(size: CGSize, pixelSize: CGSize, completion: @escaping (NSImage?) -> Void) {
                self.size = size; self.pixelSize = pixelSize; self.completion = completion
            }
            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                let snap = WKSnapshotConfiguration()
                snap.rect = CGRect(origin: .zero, size: pixelSize)
                snap.afterScreenUpdates = true
                webView.takeSnapshot(with: snap) { image, _ in
                    if let image = image {
                        image.size = self.size
                        self.completion(image)
                    } else {
                        self.completion(nil)
                    }
                }
            }
        }

        let loader = Loader(size: size, pixelSize: pixelSize, completion: completion)
        webView.navigationDelegate = loader
        objc_setAssociatedObject(webView, Unmanaged.passUnretained(webView).toOpaque(), loader, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        webView.loadHTMLString(html, baseURL: nil)
    }
}
