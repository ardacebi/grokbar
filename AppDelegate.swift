import AppKit
import SwiftUI
import WebKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover = NSPopover()
    private var eventMonitor: Any?
    private var contextMenu: NSMenu = NSMenu()
    private weak var webViewRef: WKWebView?

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

        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentSize = NSSize(width: 420, height: 640)
        popover.contentViewController = NSHostingController(rootView: WebContainerView(onCreate: { [weak self] webView in
            self?.webViewRef = webView
        }))
    _ = popover.contentViewController?.view

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            
            if let button = self.statusItem.button,
               let window = button.window,
               window.isVisible,
               let eventWindow = event.window,
               eventWindow != window {
                let popoverFrame = self.popover.contentViewController?.view.window?.frame ?? .zero
                let clickPoint = event.locationInWindow
                let screenPoint = eventWindow.convertToScreen(NSRect(origin: clickPoint, size: .zero)).origin
                
                if !popoverFrame.contains(screenPoint) && !window.frame.contains(screenPoint) {
                    self.closePopover(sender: nil)
                }
            }
        }

        configureCookiePersistence()

    buildContextMenu()

        AVCaptureDevice.requestAccess(for: .audio) { granted in

        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else if let button = statusItem.button {
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

        contextMenu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit GrokBar", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        contextMenu.addItem(quit)
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
    var onCreate: ((WKWebView) -> Void)? = nil
    func makeNSView(context: Context) -> WKWebView {
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

        if let url = URL(string: "https://grok.com/") {
            let req = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            webView.load(req)
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

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
