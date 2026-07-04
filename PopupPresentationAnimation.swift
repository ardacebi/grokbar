import AppKit
import QuartzCore

enum PopupPresentationAnimation {
    static let openPerceptualDuration: TimeInterval = 0.32
    static let closePerceptualDuration: TimeInterval = 0.26
    static let springBounce: CGFloat = 0.0
    static let presentationScale: CGFloat = 0.96
    static let presentationOpacity: CGFloat = 0.88

    static var openDuration: TimeInterval { openPerceptualDuration }
    static var closeDuration: TimeInterval { closePerceptualDuration }

    struct PresentationState: Equatable {
        var frame: NSRect
        var alpha: CGFloat
        var scale: CGFloat
        var contentOffsetX: CGFloat
    }

    static func openingStartState(finalFrame: NSRect) -> PresentationState {
        PresentationState(
            frame: finalFrame,
            alpha: presentationOpacity,
            scale: presentationScale,
            contentOffsetX: finalFrame.width
        )
    }

    static func restingState(for finalFrame: NSRect) -> PresentationState {
        PresentationState(frame: finalFrame, alpha: 1, scale: 1, contentOffsetX: 0)
    }

    static func closingEndState(from frame: NSRect) -> PresentationState {
        PresentationState(
            frame: frame,
            alpha: presentationOpacity,
            scale: presentationScale,
            contentOffsetX: frame.width
        )
    }

    static func currentState(for panel: NSWindow) -> PresentationState {
        let scale = contentScale(in: panel)
        return PresentationState(
            frame: panel.frame,
            alpha: CGFloat(panel.alphaValue),
            scale: scale,
            contentOffsetX: contentOffsetX(in: panel)
        )
    }

    static func interpolatedState(
        from: PresentationState,
        to: PresentationState,
        progress: CGFloat
    ) -> PresentationState {
        PresentationState(
            frame: SpringTiming.interpolate(from.frame, to.frame, progress: progress),
            alpha: SpringTiming.interpolate(from.alpha, to.alpha, progress: progress),
            scale: SpringTiming.interpolate(from.scale, to.scale, progress: progress),
            contentOffsetX: SpringTiming.interpolate(
                from.contentOffsetX,
                to.contentOffsetX,
                progress: progress
            )
        )
    }

    static func prepareForPresentation(_ panel: NSWindow) {
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.contentView?.displayIfNeeded()
    }

    static func present(
        _ panel: NSWindow,
        finalFrame: NSRect,
        onPresented: (() -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        prepareForPresentation(panel)

        var from = panel.isVisible ? currentState(for: panel) : openingStartState(finalFrame: finalFrame)
        from.frame = finalFrame
        let to = restingState(for: finalFrame)

        applyPresentationState(from, to: panel)
        panel.orderFront(nil)
        onPresented?()

        runSpringPresentation(
            on: panel,
            from: from,
            to: to,
            perceptualDuration: openPerceptualDuration,
            bounce: springBounce,
            completion: completion
        )
    }

    static func dismiss(
        _ panel: NSWindow,
        finalFrame: NSRect,
        completion: @escaping () -> Void
    ) {
        let closing = closingEndState(from: finalFrame)
        let from = dismissStartState(for: panel, finalFrame: finalFrame)

        applyPresentationState(from, to: panel)

        runSpringPresentation(
            on: panel,
            from: from,
            to: closing,
            perceptualDuration: closePerceptualDuration,
            bounce: springBounce,
            completion: {
                panel.orderOut(nil)
                resetContentTransform(in: panel)
                completion()
            }
        )
    }

    static func dismissStartState(for panel: NSWindow, finalFrame: NSRect) -> PresentationState {
        var current = currentState(for: panel)
        current.frame = finalFrame
        return current
    }

    static func cancel(for panel: NSWindow) {
        PresentationSession.cancel(for: panel)
    }

    static func applyPresentationState(
        _ state: PresentationState,
        to panel: NSWindow,
        animated: Bool = false
    ) {
        if animated {
            panel.animator().setFrame(state.frame, display: true)
            panel.animator().alphaValue = state.alpha
        } else {
            panel.setFrame(state.frame, display: true)
            panel.alphaValue = state.alpha
        }
        applyContentTransform(
            scale: state.scale,
            horizontalOffset: state.contentOffsetX,
            to: panel
        )
    }

    private static func contentScale(in panel: NSWindow) -> CGFloat {
        guard let transform = presentationContentView(in: panel)?.layer?.transform else { return 1 }
        return CGFloat(transform.m11)
    }

    private static func contentOffsetX(in panel: NSWindow) -> CGFloat {
        guard let transform = presentationContentView(in: panel)?.layer?.transform else { return 0 }
        return CGFloat(transform.m41)
    }

    private static func presentationContentView(in panel: NSWindow) -> NSView? {
        if let popupPanel = panel as? MenuBarPopupPanel {
            return popupPanel.presentationContentView
        }
        return panel.contentView
    }

    private static func applyContentTransform(
        scale: CGFloat,
        horizontalOffset: CGFloat,
        to panel: NSWindow
    ) {
        guard let contentView = presentationContentView(in: panel) else { return }
        contentView.wantsLayer = true
        guard let layer = contentView.layer else { return }

        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        if abs(scale - 1) < 0.001, abs(horizontalOffset) < 0.001 {
            layer.transform = CATransform3DIdentity
        } else {
            var transform = CATransform3DMakeScale(scale, scale, 1)
            transform.m41 = horizontalOffset
            layer.transform = transform
        }
    }

    private static func resetContentTransform(in panel: NSWindow) {
        guard let layer = presentationContentView(in: panel)?.layer else { return }
        layer.transform = CATransform3DIdentity
        layer.opacity = 1
    }

    private static func runSpringPresentation(
        on panel: NSWindow,
        from: PresentationState,
        to: PresentationState,
        perceptualDuration: TimeInterval,
        bounce: CGFloat,
        completion: @escaping () -> Void
    ) {
        PresentationSession.run(
            on: panel,
            from: from,
            to: to,
            perceptualDuration: perceptualDuration,
            bounce: bounce,
            completion: {
                resetContentTransform(in: panel)
                applyPresentationState(to, to: panel)
                completion()
            }
        )
    }
}

private final class PresentationSession {
    private static var sessions: [ObjectIdentifier: PresentationSession] = [:]

    private weak var panel: NSWindow?
    private let from: PopupPresentationAnimation.PresentationState
    private let to: PopupPresentationAnimation.PresentationState
    private let perceptualDuration: TimeInterval
    private let bounce: CGFloat
    private let completion: () -> Void
    private let settlingDuration: TimeInterval

    private var startTime: CFTimeInterval?
    private var timer: Timer?
    private var didComplete = false

    private init(
        panel: NSWindow,
        from: PopupPresentationAnimation.PresentationState,
        to: PopupPresentationAnimation.PresentationState,
        perceptualDuration: TimeInterval,
        bounce: CGFloat,
        completion: @escaping () -> Void
    ) {
        self.panel = panel
        self.from = from
        self.to = to
        self.perceptualDuration = perceptualDuration
        self.bounce = bounce
        self.completion = completion
        self.settlingDuration = SpringTiming.settlingDuration(
            perceptualDuration: perceptualDuration,
            bounce: bounce
        )
    }

    static func cancel(for panel: NSWindow) {
        let key = ObjectIdentifier(panel)
        sessions[key]?.invalidate()
        sessions[key] = nil
    }

    static func run(
        on panel: NSWindow,
        from: PopupPresentationAnimation.PresentationState,
        to: PopupPresentationAnimation.PresentationState,
        perceptualDuration: TimeInterval,
        bounce: CGFloat,
        completion: @escaping () -> Void
    ) {
        cancel(for: panel)

        let session = PresentationSession(
            panel: panel,
            from: from,
            to: to,
            perceptualDuration: perceptualDuration,
            bounce: bounce,
            completion: completion
        )

        sessions[ObjectIdentifier(panel)] = session
        session.start()
    }

    private func start() {
        startTime = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    private func tick() {
        guard let panel, let startTime else { return }

        let elapsed = CACurrentMediaTime() - startTime
        let progress = SpringTiming.progress(
            elapsed: elapsed,
            perceptualDuration: perceptualDuration,
            bounce: bounce
        )
        let state = PopupPresentationAnimation.interpolatedState(
            from: from,
            to: to,
            progress: progress
        )
        PopupPresentationAnimation.applyPresentationState(state, to: panel)

        if progress >= 0.999 || elapsed >= settlingDuration {
            finish()
        }
    }

    private func finish() {
        guard !didComplete else { return }
        didComplete = true
        invalidate()
        completion()
    }

    private func invalidate() {
        timer?.invalidate()
        timer = nil
        if let panel {
            Self.sessions[ObjectIdentifier(panel)] = nil
        }
    }
}
