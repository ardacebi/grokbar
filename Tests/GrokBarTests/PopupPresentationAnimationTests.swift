import XCTest
@testable import GrokBar

final class PopupPresentationAnimationTests: XCTestCase {
    func testOpeningStartFrameIsSmallerAndOffsetAboveFinalFrame() {
        let finalFrame = NSRect(x: 100, y: 200, width: 420, height: 640)
        let startFrame = PopupPresentationAnimation.openingStartFrame(finalFrame: finalFrame)

        XCTAssertLessThan(startFrame.width, finalFrame.width)
        XCTAssertLessThan(startFrame.height, finalFrame.height)
        XCTAssertGreaterThan(startFrame.minY, finalFrame.minY)
        XCTAssertEqual(startFrame.midX, finalFrame.midX, accuracy: 0.5)
    }

    func testAnimationDurationsAreSnappy() {
        XCTAssertEqual(PopupPresentationAnimation.openDuration, 0.15, accuracy: 0.001)
        XCTAssertLessThan(PopupPresentationAnimation.closeDuration, PopupPresentationAnimation.openDuration)
    }

    func testPopupChromeUsesSlightCornerRadius() {
        XCTAssertEqual(PopupChromeStyle.cornerRadius, 12)
        XCTAssertGreaterThan(PopupChromeStyle.cornerRadius, 0)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 300))
        PopupChromeStyle.apply(to: view)

        XCTAssertEqual(view.layer?.cornerRadius, PopupChromeStyle.cornerRadius)
        XCTAssertTrue(view.layer?.masksToBounds == true)
    }
}