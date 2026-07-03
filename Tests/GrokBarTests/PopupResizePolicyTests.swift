import XCTest
import Combine
@testable import GrokBar

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
