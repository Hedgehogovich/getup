import Foundation

/// One-shot timer re-armed after each fire to the next `xx:<fireMinute>`.
final class StretchScheduler {
    private let fireMinute: () -> Int       // closure so menu/prefs changes pick up live
    private let onFire: () -> Void
    private var timer: Timer?

    init(fireMinute: @escaping () -> Int, onFire: @escaping () -> Void) {
        self.fireMinute = fireMinute
        self.onFire = onFire
    }

    func start() { scheduleNext() }

    /// Pure: compute the next `xx:<fireMinute>:00` that is strictly after `now`.
    /// Extracted for unit tests — feed canned `now` + minute, assert the returned date.
    /// `fireMinute` is clamped to `0...59`.
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

    private func scheduleNext() {
        let now = Date()
        let fire = Self.nextFireDate(after: now, fireMinute: fireMinute())
        let interval = fire.timeIntervalSince(now)
        NSLog("getup: next fire in \(Int(interval))s (\(fire))")

        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in self?.fire() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func fire() {
        onFire()
        scheduleNext()
    }
}
