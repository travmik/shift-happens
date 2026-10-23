import AppKit
import ApplicationServices

/// Live Accessibility permission state, polled while UI that displays it is visible.
///
/// macOS exposes no public notification for Accessibility grants, so consumers
/// start polling while visible and stop when hidden (spec: welcome-onboarding).
@MainActor
public final class AccessibilityStatus: ObservableObject {
    @Published private(set) public var granted: Bool

    private let check: () -> Bool
    private let interval: TimeInterval
    private var timer: Timer?

    public init(check: @escaping () -> Bool = { AXIsProcessTrusted() },
                interval: TimeInterval = 1.0) {
        self.check = check
        self.interval = interval
        self.granted = check()
    }

    deinit { timer?.invalidate() }

    /// Re-reads the permission immediately.
    public func refresh() {
        granted = check()
    }

    /// Starts polling on the main run loop. Safe to call repeatedly.
    public func startPolling() {
        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        self.timer = timer
    }

    /// Stops polling. The stored value remains (last known state).
    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
