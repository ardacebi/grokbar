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
    }

    static func openingStartFrame(finalFrame: NSRect) -> NSRect {
        NSRect(
            x: finalFrame.maxX,
            y: finalFrame.origin.y,
            width: finalFrame.width,
            height: finalFrame.height
        )
    }

    static func openingStartState(finalFrame: NSRect) -> PresentationState {
        PresentationState(
            frame: openingStartFrame(finalFrame: finalFrame),
            alpha: presentationOpacity,
            scale: presentationScale
        )
    }

    static func restingState(for finalFrame: NSRect) -> PresentationState {
        PresentationState(frame: finalFrame, alpha: 1, scale: 1)
    }

    static func closingEndState(from frame: NSRect) -> PresentationState {
        PresentationState(
            frame: openingStartFrame(finalFrame: frame),
            alpha: presentationOpacity,
            scale: presentationScale
        )
    }

    static func currentState(for panel: NSWindow) -> PresentationState {
        let scale = contentScale(in: panel)
        return PresentationState(
            frame: panel.frame,
            alpha: CGFloat(panel.alphaValue),
            scale: scale
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
            scale: SpringTiming.interpolate(from.scale, to.scale, progress: progress)
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

        let from = openingStartState(finalFrame: finalFrame)
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
        let resting = restingState(for: finalFrame)
        let closing = closingEndState(from: finalFrame)
        let from = dismissStartState(for: panel, finalFrame: finalFrame)

        if from == resting {
            applyPresentationState(from, to: panel)
        }

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
        let resting = restingState(for: finalFrame)
        let opening = openingStartState(finalFrame: finalFrame)
        let current = currentState(for: panel)

        let totalTravel = opening.frame.origin.x - resting.frame.origin.x
        guard totalTravel > 1 else { return resting }

        let traveled = opening.frame.origin.x - current.frame.origin.x
        let openFraction = min(1, max(0, traveled / totalTravel))

        if openFraction >= 0.55 {
            return resting
        }

        return PresentationState(
            frame: current.frame,
            alpha: current.alpha,
            scale: current.scale
        )
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
        applyContentScale(state.scale, to: panel)
    }

    private static func contentScale(in panel: NSWindow) -> CGFloat {
        guard let transform = panel.contentView?.layer?.transform else { return 1 }
        return CGFloat(transform.m11)
    }

    private static func applyContentScale(_ scale: CGFloat, to panel: NSWindow) {
        guard let contentView = panel.contentView else { return }
        contentView.wantsLayer = true
        guard let layer = contentView.layer else { return }

        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        if abs(scale - 1) < 0.001 {
            layer.transform = CATransform3DIdentity
        } else {
            layer.transform = CATransform3DMakeScale(scale, scale, 1)
        }
    }

    private static func resetContentTransform(in panel: NSWindow) {
        guard let layer = panel.contentView?.layer else { return }
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