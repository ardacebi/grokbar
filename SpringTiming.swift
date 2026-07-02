import AppKit
import Foundation
import QuartzCore

enum SpringTiming {
    static func progress(
        elapsed: TimeInterval,
        perceptualDuration: TimeInterval,
        bounce: CGFloat
    ) -> CGFloat {
        guard perceptualDuration > 0 else { return 1 }
        if elapsed >= perceptualDuration { return 1 }
        if elapsed <= 0 { return 0 }

        let normalized = CGFloat(elapsed / perceptualDuration)

        if bounce <= 0.001 {
            let rate: CGFloat = 6.90775527898
            return 1 - CGFloat(exp(-Double(rate * normalized)))
        }

        let stiffness = pow(2 * CGFloat.pi / CGFloat(perceptualDuration), 2)
        let dampingRatio: CGFloat = 1 - bounce * 0.45
        let damping: CGFloat = 2 * dampingRatio * sqrt(stiffness)
        let omega: CGFloat = sqrt(stiffness)
        let envelope: CGFloat = CGFloat(exp(-Double(damping * CGFloat(elapsed))))
        let oscillation: CGFloat = CGFloat(cos(Double(omega * CGFloat(elapsed) * (1 + bounce * 0.35))))
        return min(1, max(0, 1 - envelope * oscillation))
    }

    static func interpolate(_ from: CGFloat, _ to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    static func interpolate(_ from: NSRect, _ to: NSRect, progress: CGFloat) -> NSRect {
        NSRect(
            x: interpolate(from.origin.x, to.origin.x, progress: progress),
            y: interpolate(from.origin.y, to.origin.y, progress: progress),
            width: interpolate(from.width, to.width, progress: progress),
            height: interpolate(from.height, to.height, progress: progress)
        )
    }

    static func makeSpringAnimation(
        keyPath: String,
        from: Any?,
        to: Any?,
        perceptualDuration: TimeInterval,
        bounce: CGFloat
    ) -> CASpringAnimation {
        let spring: CASpringAnimation
        if #available(macOS 14.0, *) {
            spring = CASpringAnimation(perceptualDuration: perceptualDuration, bounce: bounce)
            spring.keyPath = keyPath
        } else {
            spring = CASpringAnimation(keyPath: keyPath)
            spring.mass = 1
            spring.stiffness = stiffness(for: perceptualDuration)
            spring.damping = damping(for: perceptualDuration, bounce: bounce)
        }
        spring.fromValue = from
        spring.toValue = to
        return spring
    }

    static func springTimingFunction(
        perceptualDuration: TimeInterval,
        bounce: CGFloat
    ) -> CAMediaTimingFunction {
        let t1 = progress(elapsed: perceptualDuration * 0.25, perceptualDuration: perceptualDuration, bounce: bounce)
        let t2 = progress(elapsed: perceptualDuration * 0.72, perceptualDuration: perceptualDuration, bounce: bounce)
        return CAMediaTimingFunction(
            controlPoints: 0.25, Float(t1), 0.72, Float(min(1, t2))
        )
    }

    static func settlingDuration(
        perceptualDuration: TimeInterval,
        bounce: CGFloat
    ) -> TimeInterval {
        makeSpringAnimation(
            keyPath: "opacity",
            from: 0,
            to: 1,
            perceptualDuration: perceptualDuration,
            bounce: bounce
        ).settlingDuration
    }

    static func stiffness(for perceptualDuration: TimeInterval) -> CGFloat {
        CGFloat(pow(2 * .pi / perceptualDuration, 2))
    }

    static func damping(for perceptualDuration: TimeInterval, bounce: CGFloat) -> CGFloat {
        let dampingRatio = 1 - bounce * 0.45
        return 2 * dampingRatio * sqrt(stiffness(for: perceptualDuration))
    }
}