import SwiftUI
import AppKit

@main
struct GrokBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows; only a menu bar extra via AppDelegate
        Settings { EmptyView() }
    }
}
