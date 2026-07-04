import XCTest
import Combine
import WebKit
@testable import GrokBar

private final class LayoutDisplayTrackingView: NSView {
    private(set) var layoutCount = 0
    private(set) var displayCount = 0

    override func layoutSubtreeIfNeeded() {
        layoutCount += 1
        super.layoutSubtreeIfNeeded()
    }

    override func displayIfNeeded() {
        displayCount += 1
        super.displayIfNeeded()
    }
}

final class PopupResizePolicyTests: XCTestCase {
    func testDraggingBottomLeftDownAndLeftGrowsPopup() {
        let start = PopupSizePreset.mid.contentSize
        let desired = PopupResizePolicy.desiredSize(
            startingAt: start,
            startMouseLocation: NSPoint(x: 500, y: 500),
            currentMouseLocation: NSPoint(x: 430, y: 390)
        )
        let index = PopupResizePolicy.continuousIndex(for: desired)
        let resized = PopupResizePolicy.interpolatedSize(at: index)

        XCTAssertGreaterThan(resized.width, start.width)
        XCTAssertGreaterThan(resized.height, start.height)
    }

    func testDraggingBottomLeftUpAndRightShrinksPopup() {
        let start = PopupSizePreset.mid.contentSize
        let desired = PopupResizePolicy.desiredSize(
            startingAt: start,
            startMouseLocation: NSPoint(x: 500, y: 500),
            currentMouseLocation: NSPoint(x: 560, y: 600)
        )
        let index = PopupResizePolicy.continuousIndex(for: desired)
        let resized = PopupResizePolicy.interpolatedSize(at: index)

        XCTAssertLessThan(resized.width, start.width)
        XCTAssertLessThan(resized.height, start.height)
    }

    func testResizeFrameKeepsTopRightAnchorFixed() {
        let visibleFrame = NSRect(x: 0, y: 40, width: 1920, height: 1040)
        let smallFrame = PopoverPresentationPolicy.panelFrame(
            visibleFrame: visibleFrame,
            contentSize: PopupSizePreset.small.contentSize
        )
        let largeFrame = PopoverPresentationPolicy.panelFrame(
            visibleFrame: visibleFrame,
            contentSize: PopupSizePreset.large.contentSize
        )

        XCTAssertEqual(smallFrame.maxX, largeFrame.maxX, accuracy: 0.001)
        XCTAssertEqual(smallFrame.maxY, largeFrame.maxY, accuracy: 0.001)
        XCTAssertLessThan(largeFrame.minX, smallFrame.minX)
        XCTAssertLessThan(largeFrame.minY, smallFrame.minY)
    }

    func testContinuousIndexSnapsToNearestPreset() {
        XCTAssertEqual(PopupResizePolicy.snappedPreset(for: 1.49), .smallMid)
        XCTAssertEqual(PopupResizePolicy.snappedPreset(for: 1.51), .mid)
    }

    func testApplyLiveResizeFrameUpdatesWindowAndLaysOutContent() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let contentView = LayoutDisplayTrackingView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        let childView = LayoutDisplayTrackingView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        contentView.addSubview(childView)
        window.contentView = contentView

        let nextFrame = NSRect(x: 100, y: 200, width: 480, height: 740)
        PopupResizePolicy.applyLiveResizeFrame(nextFrame, to: window)

        XCTAssertEqual(window.frame, nextFrame)
        XCTAssertEqual(contentView.bounds.size, nextFrame.size)
        XCTAssertGreaterThan(contentView.layoutCount, 0)
        XCTAssertGreaterThan(contentView.displayCount, 0)
        XCTAssertEqual(childView.displayCount, 0)
    }

    func testApplyLiveResizeFrameWithNilContentViewDoesNotCrash() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = nil

        let nextFrame = NSRect(x: 100, y: 200, width: 480, height: 740)
        PopupResizePolicy.applyLiveResizeFrame(nextFrame, to: window)

        XCTAssertEqual(window.frame, nextFrame)
    }

    func testWebViewBackgroundStaysClear() {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        PopupChromeStyle.configureWebViewBackground(webView)

        let configured = webView.underPageBackgroundColor?.usingColorSpace(.sRGB)
        XCTAssertNotNil(configured)
        XCTAssertEqual(configured?.alphaComponent ?? -1, 0.0, accuracy: 0.01)
    }

    func testResizePresetPublicationIsMarkedAsHandleDriven() {
        let settings = AppSettings()
        let originalPreset = settings.popupSizePreset
        let nextPreset: PopupSizePreset = originalPreset == .small ? .mid : .small
        var wasMarkedDuringPublication = false
        let cancellable = settings.$popupSizePreset.dropFirst().sink { _ in
            wasMarkedDuringPublication = settings.isUpdatingFromResizeHandle
        }

        settings.updatePresetFromResizeHandle(nextPreset)

        XCTAssertTrue(wasMarkedDuringPublication)
        withExtendedLifetime(cancellable) {}
        settings.updatePresetFromResizeHandle(originalPreset)
    }
}
