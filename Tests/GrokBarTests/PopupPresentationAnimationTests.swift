import XCTest
@testable import GrokBar

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

    private func makeMenuBarPopupPanel() -> MenuBarPopupPanel {
        let contentController = NSViewController()
        contentController.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 640))
        let panel = MenuBarPopupPanel(contentSize: NSSize(width: 420, height: 640))
        panel.setPresentedContentController(contentController)
        _ = panel.contentView
        return panel
    }

    private func presentationLayer(in panel: NSWindow) -> CALayer? {
        if let popupPanel = panel as? MenuBarPopupPanel {
            return popupPanel.presentationContentView?.layer
        }
        return panel.contentView?.layer
    }

    func testOpeningKeepsPanelFixedAndOffsetsContentFromRight() {
        let finalFrame = NSRect(x: 100, y: 200, width: 420, height: 640)
        let start = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)

        XCTAssertEqual(start.frame, finalFrame)
        XCTAssertEqual(start.contentOffsetX, finalFrame.width, accuracy: 0.001)
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
        XCTAssertEqual(spring.keyPath, "opacity")
        XCTAssertGreaterThan(SpringTiming.settlingDuration(
            perceptualDuration: PopupPresentationAnimation.openPerceptualDuration,
            bounce: 0
        ), 0.2)
    }

    func testInterpolatedStateMovesContentWithinFixedWindowFrame() {
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)
        let from = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)
        let to = PopupPresentationAnimation.restingState(for: finalFrame)
        let mid = PopupPresentationAnimation.interpolatedState(from: from, to: to, progress: 0.5)

        XCTAssertEqual(mid.frame, finalFrame)
        XCTAssertGreaterThan(mid.contentOffsetX, to.contentOffsetX)
        XCTAssertLessThan(mid.contentOffsetX, from.contentOffsetX)
        XCTAssertGreaterThan(mid.alpha, from.alpha)
        XCTAssertLessThan(mid.alpha, to.alpha + 0.01)
    }

    func testPresentKeepsPanelChromeFreeOfShadowDuringAnimation() {
        let panel = makeMenuBarPopupPanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)

        let midExpectation = expectation(description: "mid present")
        let doneExpectation = expectation(description: "present completes")
        PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
            doneExpectation.fulfill()
        })

        XCTAssertFalse(panel.hasShadow)
        XCTAssertEqual(panel.contentView?.layer?.backgroundColor, NSColor.clear.cgColor)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            XCTAssertFalse(panel.hasShadow)
            midExpectation.fulfill()
        }

        wait(for: [midExpectation, doneExpectation], timeout: 2.0)
        XCTAssertFalse(panel.hasShadow)
    }

    func testDismissKeepsPanelChromeFreeOfShadowDuringAnimation() {
        let panel = makeMenuBarPopupPanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)

        panel.setFrame(finalFrame, display: true)
        panel.alphaValue = 1
        panel.orderFront(nil)

        let midExpectation = expectation(description: "mid dismiss")
        let doneExpectation = expectation(description: "dismiss completes")

        PopupPresentationAnimation.dismiss(panel, finalFrame: finalFrame) {
            doneExpectation.fulfill()
        }

        XCTAssertFalse(panel.hasShadow)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            XCTAssertFalse(panel.hasShadow)
            midExpectation.fulfill()
        }

        wait(for: [midExpectation, doneExpectation], timeout: 2.0)
        XCTAssertFalse(panel.hasShadow)
    }

    func testPresentStartsWithContentOffsetInsideFinalFrame() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)
        let expectedStart = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)

        let expectation = expectation(description: "present completes")
        PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
            expectation.fulfill()
        })

        XCTAssertEqual(panel.frame.origin.x, finalFrame.origin.x, accuracy: 1.0)
        XCTAssertEqual(
            presentationLayer(in: panel)?.transform.m41 ?? 0,
            expectedStart.contentOffsetX,
            accuracy: 2.0
        )
        XCTAssertEqual(panel.alphaValue, expectedStart.alpha, accuracy: 0.01)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(panel.frame, finalFrame)
        XCTAssertEqual(panel.alphaValue, 1, accuracy: 0.01)
    }

    func testPresentAnimatesContentOffsetWhileWindowStaysFixed() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)
        let start = PopupPresentationAnimation.openingStartState(finalFrame: finalFrame)

        let midExpectation = expectation(description: "mid animation")
        let doneExpectation = expectation(description: "present completes")

        PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
            doneExpectation.fulfill()
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let offset = self.presentationLayer(in: panel)?.transform.m41 ?? 0
            XCTAssertEqual(panel.frame, finalFrame)
            XCTAssertGreaterThan(offset, 0)
            XCTAssertLessThan(offset, start.contentOffsetX)
            midExpectation.fulfill()
        }

        wait(for: [midExpectation, doneExpectation], timeout: 2.0)
    }

    func testPresentationStartsScaledAndFinishesAtIdentity() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)

        let doneExpectation = expectation(description: "present completes")

        PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
            doneExpectation.fulfill()
        })

        XCTAssertEqual(
            presentationLayer(in: panel)?.transform.m11 ?? 1,
            PopupPresentationAnimation.presentationScale,
            accuracy: 0.005
        )

        wait(for: [doneExpectation], timeout: 2.0)
        XCTAssertEqual(presentationLayer(in: panel)?.transform.m11 ?? 1, 1, accuracy: 0.001)
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

    func testPresentInterruptedDuringCloseContinuesFromCurrentOffset() {
        let panel = makePanel()
        let finalFrame = NSRect(x: 200, y: 300, width: 420, height: 640)

        panel.setFrame(finalFrame, display: true)
        panel.alphaValue = 1
        panel.orderFront(nil)

        let interruptedExpectation = expectation(description: "interrupted open completes")

        PopupPresentationAnimation.dismiss(panel, finalFrame: finalFrame, completion: {})

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let offsetBeforeReopen = self.presentationLayer(in: panel)?.transform.m41 ?? 0
            PopupPresentationAnimation.present(panel, finalFrame: finalFrame, completion: {
                interruptedExpectation.fulfill()
            })

            let offsetAfterReopen = self.presentationLayer(in: panel)?.transform.m41 ?? 0
            XCTAssertEqual(panel.frame, finalFrame)
            XCTAssertGreaterThan(offsetBeforeReopen, 0)
            XCTAssertLessThan(offsetBeforeReopen, finalFrame.width)
            XCTAssertEqual(offsetAfterReopen, offsetBeforeReopen, accuracy: 2.0)
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
        XCTAssertEqual(start.contentOffsetX, 0, accuracy: 0.01)
    }

    func testPopupClipsSlidingContentToTargetScreen() {
        let targetScreenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let adjacentScreenFrame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)
        let finalFrame = PopoverPresentationPolicy.panelFrame(
            visibleFrame: targetScreenFrame,
            contentSize: NSSize(width: 420, height: 640)
        )
        let contentController = NSViewController()
        contentController.view = NSView(frame: NSRect(origin: .zero, size: finalFrame.size))
        let panel = MenuBarPopupPanel(contentSize: finalFrame.size)
        panel.setPresentedContentController(contentController)

        let completion = expectation(description: "presentation completes")
        PopupPresentationAnimation.present(panel, finalFrame: finalFrame) {
            completion.fulfill()
        }

        XCTAssertEqual(panel.frame, finalFrame)
        XCTAssertFalse(panel.frame.intersects(adjacentScreenFrame))
        XCTAssertEqual(panel.contentView?.layer?.backgroundColor, NSColor.clear.cgColor)
        XCTAssertFalse(panel.hasShadow)

        wait(for: [completion], timeout: 2.0)
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
        XCTAssertEqual(view.layer?.backgroundColor, NSColor.clear.cgColor)
    }

    func testClippingViewStaysClearSoSlideAnimationDoesNotShowBlackPlate() {
        let contentController = NSViewController()
        contentController.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 300))
        let panel = MenuBarPopupPanel(contentSize: NSSize(width: 200, height: 300))
        panel.setPresentedContentController(contentController)
        _ = panel.contentView

        XCTAssertEqual(panel.contentView?.layer?.backgroundColor, NSColor.clear.cgColor)
        XCTAssertFalse(panel.hasShadow)
    }
}
