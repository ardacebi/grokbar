import AVFoundation
import WebKit

enum MediaCapturePermissionPolicy {
    static func isTrustedGrokHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        return normalized == "grok.com" || normalized.hasSuffix(".grok.com")
    }

    static func immediateDecision(
        host: String,
        captureType: WKMediaCaptureType,
        microphoneStatus: AVAuthorizationStatus
    ) -> WKPermissionDecision? {
        guard isTrustedGrokHost(host) else { return .prompt }
        guard captureType == .microphone else { return .prompt }

        switch microphoneStatus {
        case .authorized:
            return .grant
        case .denied, .restricted:
            return .deny
        case .notDetermined:
            return nil
        @unknown default:
            return .deny
        }
    }
}
