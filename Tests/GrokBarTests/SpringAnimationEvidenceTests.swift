import XCTest
@testable import GrokBar

final class SpringAnimationEvidenceTests: XCTestCase {
    private let scratchPath = "/var/folders/yk/b5slg6ln6jlc9y0vqmbhzt0w0000gn/T/grok-goal-c63ee73352f2/implementer/spring-animation-evidence.log"

    func testCaptureSpringMidAnimationEvidence() {
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))

        let finalFrame = NSRect(x: 250, y: 350, width: 420, height: 640)
        let start = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)

        let midExpectation = expectation(description: "mid")
        let doneExpectation = expectation(description: "done")

        PopupPresentationAnimation.present(panel, finalFrame: finalFrame) {
            doneExpectation.fulfill()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let midFrame = panel.frame
            let midScale = panel.contentView?.layer?.transform.m11 ?? 1
            let evidence = """
            spring-mid-animation-evidence
            start.x=\(start.frame.origin.x)
            mid.x=\(midFrame.origin.x)
            end.x=\(finalFrame.origin.x)
            mid-alpha=\(panel.alphaValue)
            mid-scale=\(midScale)
            perceptual-open=\(PopupPresentationAnimation.openPerceptualDuration)
            caspring-settling=\(SpringTiming.settlingDuration(perceptualDuration: PopupPresentationAnimation.openPerceptualDuration, bounce: 0))
            """
            try? evidence.write(toFile: self.scratchPath, atomically: true, encoding: .utf8)

            let inMotion = midFrame.origin.x > finalFrame.origin.x + 1
                && midFrame.origin.x < start.frame.origin.x
            let scaleInMotion = midScale > PopupPresentationAnimation.presentationScale + 0.001
                && midScale < 0.999
            XCTAssertTrue(inMotion || scaleInMotion, "Expected visible in-flight spring state")
            midExpectation.fulfill()
        }

        wait(for: [midExpectation, doneExpectation], timeout: 2.0)
        XCTAssertEqual(panel.frame, finalFrame)
    }
}