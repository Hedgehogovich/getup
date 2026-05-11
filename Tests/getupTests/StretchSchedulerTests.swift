import Foundation
import Testing
@testable import getup

@Suite("StretchScheduler — pure next-fire math")
struct StretchSchedulerTests {
    /// Use UTC + Gregorian so canned dates produce deterministic comparisons regardless
    /// of the host's timezone or locale.
    private static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Build a UTC date for a given Y-M-D H:M:S. Forces the test to be locale-independent.
    private static func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
        let comps = DateComponents(
            calendar: utc, timeZone: TimeZone(identifier: "UTC"),
            year: y, month: mo, day: d, hour: h, minute: mi, second: s
        )
        return comps.date!
    }

    @Test func sameHour_whenNowIsBeforeFireMinute() {
        let now = Self.date(2026, 5, 6, 10, 30, 0)
        let fire = StretchScheduler.nextFireDate(after: now, fireMinute: 50, calendar: Self.utc)
        #expect(fire == Self.date(2026, 5, 6, 10, 50, 0))
    }

    @Test func nextHour_whenNowIsAfterFireMinute() {
        let now = Self.date(2026, 5, 6, 10, 55, 0)
        let fire = StretchScheduler.nextFireDate(after: now, fireMinute: 50, calendar: Self.utc)
        #expect(fire == Self.date(2026, 5, 6, 11, 50, 0))
    }

    @Test func strictlyAfter_whenNowEqualsTargetMinute() {
        let now = Self.date(2026, 5, 6, 10, 50, 0)
        let fire = StretchScheduler.nextFireDate(after: now, fireMinute: 50, calendar: Self.utc)
        #expect(fire == Self.date(2026, 5, 6, 11, 50, 0))
    }

    @Test func strictlyAfter_whenNowEqualsTopOfHour_andMinuteIsZero() {
        let now = Self.date(2026, 5, 6, 10, 0, 0)
        let fire = StretchScheduler.nextFireDate(after: now, fireMinute: 0, calendar: Self.utc)
        #expect(fire == Self.date(2026, 5, 6, 11, 0, 0))
    }

    @Test func wrapsAcrossDayBoundary() {
        let now = Self.date(2026, 5, 6, 23, 55, 0)
        let fire = StretchScheduler.nextFireDate(after: now, fireMinute: 50, calendar: Self.utc)
        #expect(fire == Self.date(2026, 5, 7, 0, 50, 0))
    }

    @Test func minuteIsClampedBelow() {
        let now = Self.date(2026, 5, 6, 10, 30, 0)
        let fire = StretchScheduler.nextFireDate(after: now, fireMinute: -5, calendar: Self.utc)
        // -5 → clamped to 0; 10:00 already passed, so next is 11:00
        #expect(fire == Self.date(2026, 5, 6, 11, 0, 0))
    }

    @Test func minuteIsClampedAbove() {
        let now = Self.date(2026, 5, 6, 10, 30, 0)
        let fire = StretchScheduler.nextFireDate(after: now, fireMinute: 99, calendar: Self.utc)
        // 99 → clamped to 59
        #expect(fire == Self.date(2026, 5, 6, 10, 59, 0))
    }
}
