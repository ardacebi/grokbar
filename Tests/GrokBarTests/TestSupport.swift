import XCTest

extension XCTestCase {
    func waitUntil(
        _ description: String,
        timeout: TimeInterval = 3,
        condition: @escaping () -> Bool
    ) {
        let expectation = expectation(description: description)
        let deadline = Date().addingTimeInterval(timeout)

        func poll() {
            if condition() {
                expectation.fulfill()
            } else if Date() >= deadline {
                XCTFail("Timed out waiting for \(description)")
                expectation.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
            }
        }

        poll()
        wait(for: [expectation], timeout: timeout + 0.5)
    }
}
