import SwiftUI
import AppKit
import WebKit

struct PopoverRootView: View {
    @ObservedObject var settings: AppSettings
    var onWebViewCreate: ((WKWebView) -> Void)?

    var body: some View {
        WebContainerView(settings: settings, onCreate: onWebViewCreate)
    }
}
