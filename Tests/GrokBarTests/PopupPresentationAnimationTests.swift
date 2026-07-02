import XCTest
@testable import GrokBar
import QuartzCore

final class PopupPresentationAnimationTests: XCTestCase {
    private func makePanel() -> NSWindow {
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        return panel
    }

    func testOpeningStartFrameSlidesInFromRight() {
        let finalFrame = NSRect(x: 100, y: 200, width: 420, height: 640)
        let startFrame = PopupPresentationAnimation.openingStartFrame(finalFrame: finalFrame)

        XCTAssertEqual(startFrame.origin.x, finalFrame.maxX, accuracy: 0.5)
        XCTAssertEqual(startFrame.origin.y, finalFrame.origin.y, accuracy: 0.5)
        XCTAssertEqual(startFrame.size, finalFrame.size)
    }

    func testClosingEndStateMirrorsOpeningStartState() {
        let frame = NSRect(x: 100, y: 200, width: 420, height: 640)
        let opening = PopupPresentationAnimation.openingStartState(finalFrame: frame)
        let closing = PopupPresentationAnimation.closingEndState(from: frame)

        XCTAssertEqual(closing.frame, opening.frame)
        XCTAssertEqual(closing.alpha, opening.alpha, accuracy: 0.001)
        XCTAssertEqual(closing.scale, opening.scale, accuracy: 0.001)
    }

    func testSpringTimingUsesSnappyNearZeroBounceDuration() {
        XCTAssertGreaterThanOrEqual(PopupPresentationAnimation.openPerceptualDuration, 0.25)
        XCTAssertLessThanOrEqual(PopupPresentationAnimation.openPerceptualDuration, 0.35)
        XCTAssertLessThan(PopupPresentationAnimation.springBounce, 0.05)
        XCTAssertLessThan(PopupPresentationAnimation.closePerceptualDuration, PopupPresentationAnimation.openPerceptualDuration)
    }

    func testSpringProgressReachesOneAtPerceptualDuration() {
        let duration = PopupPresentationAnimation.openPerceptualDuration
        let end = SpringTiming.progress(elapsed: duration, perceptualDuration: duration, bounce: 0)
        XCTAssertEqual(end, 1, accuracy: 0.0001)
    }

    func testSpringAnimationUsesCASpringAnimation() {
        let spring = SpringTiming.makeSpringAnimation(
            keyPath: "opacity",
            from: 0.88,
            to: 1,
            perceptualDuration: PopupPresentationAnimation.openPerceptualDuration,
            bounce: 0
        )
        XCTAssertTrue(spring is CASpringAnimation)
        XCTAssertGreaterThan(SpringTiming.settlingDuration(
            perceptualDuration: PopupPresentationAnimation.openPerceptualDuration,
            bounce: 0
        ), 0.2)
    }

    func testInterpolatedStateMovesWindowFrameBetweenStartAndEnd() {
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)
        let from = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)
        let to = PopupPresentationAnimation.restingState(for: finalFrame)
        let mid = PopupPresentationAnimation.interpolatedState(from: from, to: to, progress: 0.5)

        XCTAssertGreaterThan(mid.frame.origin.x, to.frame.origin.x)
        XCTAssertLessThan(mid.frame.origin.x, from.frame.origin.x)
        XCTAssertGreaterThan(mid.alpha, from.alpha)
        XCTAssertLessThan(mid.alpha, to.alpha + 0.01)
    }

    func testPresentStartsAtOffScreenRightFrame() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)
        let expectedStart = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)

        let expectation = expectation(description: "present completes")
        PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
            expectation.fulfill()
        })

        XCTAssertEqual(panel.frame.origin.x, expectedStart.frame.origin.x, accuracy: 0.5)
        XCTAssertEqual(panel.alphaValue, expectedStart.alpha, accuracy: 0.01)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(panel.frame, finalFrame)
        XCTAssertEqual(panel.alphaValue, 1, accuracy: 0.01)
    }

    func testPresentAnimatesWindowFrameDuringSpring() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)
        let start = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)

        let midExpectation = expectation(description: "mid animation")
        let doneExpectation = expectation(description: "present completes")

        PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
            doneExpectation.fulfill()
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let frame = panel.frame
            XCTAssertGreaterThan(frame.origin.x, finalFrame.origin.x)
            XCTAssertLessThan(frame.origin.x, start.frame.origin.x + 1)
            midExpectation.fulfill()
        }

        wait(for: [midExpectation, doneExpectation], timeout: 2.0)
    }

    func testPresentAnimatesScaleDuringSpring() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)

        let midExpectation = expectation(description: "mid scale")
        let doneExpectation = expectation(description: "present completes")

        PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
            doneExpectation.fulfill()
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let scale = panel.contentView?.layer?.transform.m11 ?? 1
            let inMotion = scale > PopupPresentationAnimation.presentationScale + 0.001
                && scale < 0.999
            XCTAssertTrue(
                inMotion,
                "Expected scale between \(PopupPresentationAnimation.presentationScale) and 1, got \(scale)"
            )
            midExpectation.fulfill()
        }

        wait(for: [midExpectation, doneExpectation], timeout: 2.0)
        XCTAssertEqual(panel.contentView?.layer?.transform.m11 ?? 1, 1, accuracy: 0.001)
    }

    func testDismissInterruptsInFlightPresent() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)

        let dismissExpectation = expectation(description: "dismiss completes")

        PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
            XCTFail("Present should be interrupted")
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            PopupPresentationAnimation.dismiss(panel, finalFrame: finalFrame) {
                dismissExpectation.fulfill()
            }
        }

        wait(for: [dismissExpectation], timeout: 2.0)
        XCTAssertFalse(panel.isVisible)
    }

    func testPresentInterruptsInFlightDismiss() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)

        panel.setFrame(finalFrame, display: true)
        panel.alphaValue = 1
        panel.orderFront(nil)

        let presentExpectation = expectation(description: "present completes")

        PopupPresentationAnimation.dismiss(panel, finalFrame: finalFrame, completion: {
            XCTFail("Dismiss should be interrupted")
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
                presentExpectation.fulfill()
            })
        }

        wait(for: [presentExpectation], timeout: 2.0)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.frame, finalFrame)
        XCTAssertEqual(panel.alphaValue, 1, accuracy: 0.01)
    }

    func testPresentInterruptedDuringCloseUsesCanonicalOpeningStart() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)
        let expectedStart = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)

        panel.setFrame(finalFrame, display: true)
        panel.alphaValue = 1
        panel.orderFront(nil)

        let interruptedExpectation = expectation(description: "interrupted open completes")

        PopupPresentationAnimation.dismiss(panel, finalFrame: finalFrame, completion: {})

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
                interruptedExpectation.fulfill()
            })

            XCTAssertEqual(panel.frame.origin.x, expectedStart.frame.origin.x, accuracy: 0.5)
            XCTAssertEqual(panel.alphaValue, expectedStart.alpha, accuracy: 0.01)
        }

        wait(for: [interruptedExpectation], timeout: 2.0)
        XCTAssertEqual(panel.frame, finalFrame)
    }

    func testDismissUsesRestingStartWhenMostlyOpen() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)

        panel.setFrame(finalFrame, display: true)
        panel.alphaValue = 1
        panel.orderFront(nil)

        let start = PopupPresentationAnimation.dismissStartState(for: panel, finalFrame: finalFrame)
        XCTAssertEqual(start.frame, finalFrame)
        XCTAssertEqual(start.alpha, 1, accuracy: 0.01)
        XCTAssertEqual(start.scale, 1, accuracy: 0.01)
    }

    func testPresentCallsOnPresentedBeforeCompletion() {
        let panel = makePanel()
        var presented = false
        var completed = false

        let presentedExpectation = expectation(description: "presented")
        let completedExpectation = expectation(description: "completed")

        PopupPresentationAnimation.present(
            panel,
            finalFrame: NSRect(x: 100, y: 100, width: 200, height: 300),
            onPresented: {
                presented = true
                presentedExpectation.fulfill()
            },
            completion: {
                completed = true
                completedExpectation.fulfill()
            }
        )

        wait(for: [presentedExpectation, completedExpectation], timeout: 2.0)
        XCTAssertTrue(presented)
        XCTAssertTrue(completed)
    }

    func testPopupChromeUsesSlightCornerRadius() {
        XCTAssertEqual(PopupChromeStyle.cornerRadius, 12)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 300))
        PopupChromeStyle.apply(to: view)
        XCTAssertEqual(view.layer?.cornerRadius, PopupChromeStyle.cornerRadius)
        XCTAssertNotNil(view.layer?.backgroundColor)
    }
}