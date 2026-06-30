import AppKit

enum PopupPresentationAnimation {
    static let openDuration: TimeInterval = 0.15
    static let closeDuration: TimeInterval = 0.12
    static let verticalOffset: CGFloat = 10
    static let minimumScale: CGFloat = 0.97

    static func openingStartFrame(finalFrame: NSRect) -> NSRect {
        let scale = minimumScale
        let widthDelta = finalFrame.width * (1 - scale)
        let heightDelta = finalFrame.height * (1 - scale)

        return NSRect(
            x: finalFrame.origin.x + widthDelta / 2,
            y: finalFrame.origin.y + heightDelta + verticalOffset,
            width: finalFrame.width * scale,
            height: finalFrame.height * scale
        )
    }

    static func present(
        _ panel: NSWindow,
        finalFrame: NSRect,
        completion: @escaping () -> Void
    ) {
        let startFrame = openingStartFrame(finalFrame: finalFrame)
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = openDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }, completionHandler: completion)
    }

    static func dismiss(
        _ panel: NSWindow,
        completion: @escaping () -> Void
    ) {
        let endFrame = openingStartFrame(finalFrame: panel.frame)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = closeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
            panel.setFrame(endFrame, display: false)
            completion()
        })
    }
}