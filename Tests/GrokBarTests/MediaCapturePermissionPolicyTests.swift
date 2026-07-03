import AVFoundation
import WebKit
import XCTest
@testable import GrokBar

final class MediaCapturePermissionPolicyTests: XCTestCase {
    func testOnlyGrokAndItsSubdomainsAreTrusted() {
        XCTAssertTrue(MediaCapturePermissionPolicy.isTrustedGrokHost("grok.com"))
        XCTAssertTrue(MediaCapturePermissionPolicy.isTrustedGrokHost("voice.grok.com"))
        XCTAssertFalse(MediaCapturePermissionPolicy.isTrustedGrokHost("evilgrok.com"))
        XCTAssertFalse(MediaCapturePermissionPolicy.isTrustedGrokHost("example.com"))
    }

    func testUndeterminedMicrophonePermissionDefersForSystemPrompt() {
        XCTAssertNil(
            MediaCapturePermissionPolicy.immediateDecision(
                host: "grok.com",
                captureType: .microphone,
                microphoneStatus: .notDetermined
            )
        )
    }

    func testExistingMicrophoneDecisionIsReused() {
        XCTAssertEqual(
            MediaCapturePermissionPolicy.immediateDecision(
                host: "grok.com",
                captureType: .microphone,
                microphoneStatus: .authorized
            ),
            .grant
        )
        XCTAssertEqual(
            MediaCapturePermissionPolicy.immediateDecision(
                host: "grok.com",
                captureType: .microphone,
                microphoneStatus: .denied
            ),
            .deny
        )
    }

    func testUntrustedAndNonMicrophoneRequestsUseWebKitPrompt() {
        XCTAssertEqual(
            MediaCapturePermissionPolicy.immediateDecision(
                host: "example.com",
                captureType: .microphone,
                microphoneStatus: .authorized
            ),
            .prompt
        )
        XCTAssertEqual(
            MediaCapturePermissionPolicy.immediateDecision(
                host: "grok.com",
                captureType: .camera,
                microphoneStatus: .authorized
            ),
            .prompt
        )
    }
}
