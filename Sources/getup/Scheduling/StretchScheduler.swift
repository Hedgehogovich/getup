import Foundation

@MainActor
final class StretchScheduler {
    static let defaultGraceSeconds: TimeInterval = 5 * 60

    private let fireMinute: @MainActor () -> Int   // closure so live setting changes affect the next fire.
    private let fireInterval: @MainActor () -> Int
    private let onFire: @MainActor () -> Void
    private var timer: Timer?
    private var intendedFireDate: Date?

    init(fireMinute: @escaping @MainActor () -> Int,
         fireInterval: @escaping @MainActor () -> Int,
         onFire: @escaping @MainActor () -> Void) {
        self.fireMinute = fireMinute
        self.fireInterval = fireInterval
        self.onFire = onFire
    }

    func start() { scheduleNext() }

    func reschedule() { scheduleNext() }

    nonisolated static func nextFireDate(after now: Date, fireMinute: Int, intervalMinutes: Int = 60, calendar: Calendar = .current) -> Date {
        let interval = max(1, intervalMinutes)
        let phase = max(0, min(59, fireMinute)) % interval
        let startOfDay = calendar.startOfDay(for: now)
        let minutesNow = now.timeIntervalSince(startOfDay) / 60
        let k = Int(floor((minutesNow - Double(phase)) / Double(interval)))
        let target = phase + (k + 1) * interval
        return calendar.date(byAdding: .minute, value: target, to: startOfDay) ?? now
    }

    /// Timer may fire long after `intended` (sleep / hibernation / blocked runloop). Drop stale fires.
    nonisolated static func shouldFire(now: Date, intended: Date, graceSeconds: TimeInterval) -> Bool {
        now.timeIntervalSince(intended) <= graceSeconds
    }

    private func scheduleNext() {
        let now = Date()
        let fire = Self.nextFireDate(after: now, fireMinute: fireMinute(), intervalMinutes: fireInterval())
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
