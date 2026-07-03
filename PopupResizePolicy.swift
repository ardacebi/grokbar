import AppKit

enum PopupResizePolicy {
    static let presets = PopupSizePreset.allCases.map(\.contentSize)

    static func desiredSize(
        startingAt startSize: NSSize,
        startMouseLocation: NSPoint,
        currentMouseLocation: NSPoint
    ) -> NSSize {
        NSSize(
            width: startSize.width + startMouseLocation.x - currentMouseLocation.x,
            height: startSize.height + startMouseLocation.y - currentMouseLocation.y
        )
    }

    static func continuousIndex(for desiredSize: NSSize) -> CGFloat {
        guard presets.count > 1 else { return 0 }

        var bestIndex: CGFloat = 0
        var bestDistanceSquared = CGFloat.greatestFiniteMagnitude

        for index in 0..<(presets.count - 1) {
            let start = presets[index]
            let end = presets[index + 1]
            let deltaWidth = end.width - start.width
            let deltaHeight = end.height - start.height
            let segmentLengthSquared = deltaWidth * deltaWidth + deltaHeight * deltaHeight
            guard segmentLengthSquared > 0 else { continue }

            let relativeWidth = desiredSize.width - start.width
            let relativeHeight = desiredSize.height - start.height
            let projection = (relativeWidth * deltaWidth + relativeHeight * deltaHeight) / segmentLengthSquared
            let t = min(1, max(0, projection))
            let projectedWidth = start.width + deltaWidth * t
            let projectedHeight = start.height + deltaHeight * t
            let distanceWidth = desiredSize.width - projectedWidth
            let distanceHeight = desiredSize.height - projectedHeight
            let distanceSquared = distanceWidth * distanceWidth + distanceHeight * distanceHeight

            if distanceSquared < bestDistanceSquared {
                bestDistanceSquared = distanceSquared
                bestIndex = CGFloat(index) + t
            }
        }

        return bestIndex
    }

    static func interpolatedSize(at continuousIndex: CGFloat) -> NSSize {
        guard let first = presets.first, let last = presets.last else { return .zero }

        let clamped = min(CGFloat(presets.count - 1), max(0, continuousIndex))
        if clamped <= 0 { return first }
        if clamped >= CGFloat(presets.count - 1) { return last }

        let lower = Int(floor(clamped))
        let upper = lower + 1
        let progress = clamped - CGFloat(lower)
        let start = presets[lower]
        let end = presets[upper]

        return NSSize(
            width: SpringTiming.interpolate(start.width, end.width, progress: progress),
            height: SpringTiming.interpolate(start.height, end.height, progress: progress)
        )
    }

    static func snappedPreset(for continuousIndex: CGFloat) -> PopupSizePreset {
        PopupSizePreset.from(index: Int(continuousIndex.rounded()))
    }
}
