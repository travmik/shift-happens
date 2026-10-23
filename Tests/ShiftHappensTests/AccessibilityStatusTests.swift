import XCTest
@testable import ShiftHappensCore

@MainActor
final class AccessibilityStatusTests: XCTestCase {

    func test_initialValue_comesFromCheck() {
        let status = AccessibilityStatus(check: { true }, interval: 10)
        XCTAssertTrue(status.granted)
        let denied = AccessibilityStatus(check: { false }, interval: 10)
        XCTAssertFalse(denied.granted)
    }

    func test_refresh_updatesWhenCheckChanges() {
        var granted = false
        let status = AccessibilityStatus(check: { granted }, interval: 10)
        XCTAssertFalse(status.granted)
        granted = true
        status.refresh()
        XCTAssertTrue(status.granted)
    }

    func test_startPolling_picksUpChangeWithinInterval() {
        var granted = false
        let status = AccessibilityStatus(check: { granted }, interval: 0.02)
        status.startPolling()
        defer { status.stopPolling() }

        let exp = expectation(description: "granted flips via polling")
        let cancellable = status.$granted.dropFirst().sink { value in
            if value { exp.fulfill() }
        }
        _ = cancellable

        granted = true
        wait(for: [exp], timeout: 2.0)
    }

    func test_stopPolling_freezesUpdates() {
        var granted = false
        let status = AccessibilityStatus(check: { granted }, interval: 0.02)
        status.startPolling()
        status.stopPolling()

        granted = true
        let exp = expectation(description: "no update after stop")
        exp.isInverted = true
        let cancellable = status.$granted.dropFirst().sink { _ in exp.fulfill() }
        _ = cancellable

        wait(for: [exp], timeout: 0.3)
    }
}
