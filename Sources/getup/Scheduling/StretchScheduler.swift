import Foundation

@MainActor
final class StretchScheduler {
    static let defaultGraceSeconds: TimeInterval = 5 * 60

    private let fireMinute: @MainActor () -> Int   // closure so live setting changes affect the next fire.
    private let onFire: @MainActor () -> Void
    private var timer: Timer?
    private var intendedFireDate: Date?

    init(fireMinute: @escaping @MainActor () -> Int, onFire: @escaping @MainActor () -> Void) {
        self.fireMinute = fireMinute
        self.onFire = onFire
    }

    func start() { scheduleNext() }

    /// Re-arm against the current `fireMinute()` value. Call after a live setting change.
    func reschedule() { scheduleNext() }

    /// Next `xx:<fireMinute>:00` strictly after `now`. Pure for unit tests. fireMinute clamped to 0...59.
    static func nextFireDate(after now: Date, fireMinute: Int, calendar: Calendar = .current) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        comps.minute = max(0, min(59, fireMinute))
        comps.second = 0
        guard var fire = calendar.date(from: comps) else { return now }
        if fire <= now {
            fire = calendar.date(byAdding: .hour, value: 1, to: fire) ?? fire.addingTimeInterval(3600)
        }
        return fire
    }

    /// Timer may fire long after `intended` (sleep / hibernation / blocked runloop). Drop stale fires.
    static func shouldFire(now: Date, intended: Date, graceSeconds: TimeInterval) -> Bool {
        now.timeIntervalSince(intended) <= graceSeconds
    }

    private func scheduleNext() {
        let now = Date()
        let fire = Self.nextFireDate(after: now, fireMinute: fireMinute())
        intendedFireDate = fire
        let interval = fire.timeIntervalSince(now)
        NSLog("getup: next fire in \(Int(interval))s (\(fire))")

        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func fire() {
        let now = Date()
        if let intended = intendedFireDate,
           Self.shouldFire(now: now, intended: intended, graceSeconds: Self.defaultGraceSeconds) {
            onFire()
        } else if let intended = intendedFireDate {
            NSLog("getup: skipped stale fire — \(Int(now.timeIntervalSince(intended)))s past intended \(intended)")
        }
        intendedFireDate = nil
        scheduleNext()
    }
}
