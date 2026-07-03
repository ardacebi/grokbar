import XCTest
@testable import GrokBar

final class SpringAnimationEvidenceTests: XCTestCase {
    func testCaptureSpringMidAnimationEvidence() {
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))

        let finalFrame = NSRect(x: 250, y: 350, width: 420, height: 640)
        let midExpectation = expectation(description: "mid")
        let doneExpectation = expectation(description: "done")

        PopupPresentationAnimation.present(panel, finalFrame: finalFrame) {
            doneExpectation.fulfill()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let midOffset = panel.contentView?.layer?.transform.m41 ?? 0
            let midScale = panel.contentView?.layer?.transform.m11 ?? 1
            let offsetInMotion = midOffset > 1 && midOffset < finalFrame.width
            let scaleInMotion = midScale > PopupPresentationAnimation.presentationScale + 0.001
                && midScale < 0.999
            XCTAssertEqual(panel.frame, finalFrame)
            XCTAssertTrue(offsetInMotion || scaleInMotion, "Expected visible in-flight spring state")
            midExpectation.fulfill()
        }

        wait(for: [midExpectation, doneExpectation], timeout: 2.0)
        XCTAssertEqual(panel.frame, finalFrame)
    }
}
