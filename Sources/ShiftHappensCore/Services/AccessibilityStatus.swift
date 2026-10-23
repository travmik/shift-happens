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
    private var pollers = 0

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

    /// Registers a polling consumer (a visible window) and starts the timer if
    /// this is the only one. Reference-counted so several windows can share one
    /// status object; the timer stops when the last consumer releases.
    public func startPolling() {
        pollers += 1
        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        self.timer = timer
    }

    /// Releases a polling consumer. The timer stops when none remain; the
    /// stored value stays (last known state).
    public func stopPolling() {
        pollers = max(pollers - 1, 0)
        guard pollers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }
}
