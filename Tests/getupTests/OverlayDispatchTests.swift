import Foundation
import Testing
@testable import getup

@Suite("OverlayDispatch — shouldFire")
struct OverlayDispatchTests {
    /// Build a Date at the given (hour, minute) on a fixed reference day so tests are
    /// timezone-independent (Calendar uses local TZ, but we anchor against the same TZ for
    /// both construction + check).
    private static func date(hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 1
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    @Test func quietHoursDisabledAlwaysFires() {
        var s = Settings()
        s.quietHoursEnabled = false
        s.quietHoursStartMinutes = 22 * 60
        s.quietHoursEndMinutes = 7 * 60
        // Even at 3am with a window, disabled → fires.
        #expect(OverlayDispatch.shouldFire(now: Self.date(hour: 3, minute: 0), settings: s))
    }

    @Test func enabledOutsideWindowFires() {
        var s = Settings()
        s.quietHoursEnabled = true
        s.quietHoursStartMinutes = 22 * 60
        s.quietHoursEndMinutes = 7 * 60
        #expect(OverlayDispatch.shouldFire(now: Self.date(hour: 12, minute: 0), settings: s))
        #expect(OverlayDispatch.shouldFire(now: Self.date(hour: 7, minute: 0), settings: s))  // end-exclusive
    }

    @Test func enabledInsideWindowSuppresses() {
        var s = Settings()
        s.quietHoursEnabled = true
        s.quietHoursStartMinutes = 22 * 60
        s.quietHoursEndMinutes = 7 * 60
        #expect(!OverlayDispatch.shouldFire(now: Self.date(hour: 23, minute: 0), settings: s))
        #expect(!OverlayDispatch.shouldFire(now: Self.date(hour: 3, minute: 0), settings: s))
        #expect(!OverlayDispatch.shouldFire(now: Self.date(hour: 22, minute: 0), settings: s))  // start-inclusive
    }

    @Test func nonCrossingWindowAlsoWorks() {
        var s = Settings()
        s.quietHoursEnabled = true
        s.quietHoursStartMinutes = 12 * 60      // noon
        s.quietHoursEndMinutes = 14 * 60        // 2pm
        #expect(!OverlayDispatch.shouldFire(now: Self.date(hour: 13, minute: 0), settings: s))
        #expect(OverlayDispatch.shouldFire(now: Self.date(hour: 11, minute: 59), settings: s))
        #expect(OverlayDispatch.shouldFire(now: Self.date(hour: 14, minute: 0), settings: s))
    }

    @Test func emptyWindowAlwaysFires() {
        var s = Settings()
        s.quietHoursEnabled = true
        s.quietHoursStartMinutes = 9 * 60
        s.quietHoursEndMinutes = 9 * 60         // start == end → empty
        #expect(OverlayDispatch.shouldFire(now: Self.date(hour: 9, minute: 0), settings: s))
    }
}

@Suite("SnoozeDecision — fireDate")
struct SnoozeDecisionTests {
    @Test func tenMinutesAdvancesByTenMinutes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fire = SnoozeDecision.fireDate(from: now, snoozeMinutes: 10)
        #expect(fire.timeIntervalSince(now) == 600)
    }

    @Test func defaultIsTenMinutes() {
        #expect(SnoozeDecision.defaultSnoozeMinutes == 10)
        let now = Date()
        let fire = SnoozeDecision.fireDate(from: now, snoozeMinutes: SnoozeDecision.defaultSnoozeMinutes)
        #expect(fire.timeIntervalSince(now) == 600)
    }

    @Test func zeroOrNegativeClampsToOneMinute() {
        let now = Date()
        #expect(SnoozeDecision.fireDate(from: now, snoozeMinutes: 0).timeIntervalSince(now) == 60)
        #expect(SnoozeDecision.fireDate(from: now, snoozeMinutes: -5).timeIntervalSince(now) == 60)
    }
}
