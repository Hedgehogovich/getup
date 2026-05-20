import Foundation
import Testing
@testable import getup

@Suite("QuietHours — window math")
struct QuietHoursTests {
    private static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 20
        c.hour = hour; c.minute = minute
        return utc.date(from: c)!
    }

    @Test func sameDayRangeIncludesStartExcludesEnd() {
        let now = Self.makeDate(hour: 13, minute: 0)
        #expect(QuietHours.isWithin(now: now, startMinutes: 9*60, endMinutes: 17*60, calendar: Self.utc))
        #expect(QuietHours.isWithin(now: Self.makeDate(hour: 9, minute: 0),  startMinutes: 9*60, endMinutes: 17*60, calendar: Self.utc))
        #expect(!QuietHours.isWithin(now: Self.makeDate(hour: 17, minute: 0), startMinutes: 9*60, endMinutes: 17*60, calendar: Self.utc))
        #expect(!QuietHours.isWithin(now: Self.makeDate(hour: 18, minute: 0), startMinutes: 9*60, endMinutes: 17*60, calendar: Self.utc))
    }

    @Test func crossMidnightRangeWrapsCorrectly() {
        // 22:00 → 07:00
        let start = 22 * 60
        let end = 7 * 60
        #expect(QuietHours.isWithin(now: Self.makeDate(hour: 23, minute: 30), startMinutes: start, endMinutes: end, calendar: Self.utc))
        #expect(QuietHours.isWithin(now: Self.makeDate(hour: 2,  minute: 0),  startMinutes: start, endMinutes: end, calendar: Self.utc))
        #expect(QuietHours.isWithin(now: Self.makeDate(hour: 6,  minute: 59), startMinutes: start, endMinutes: end, calendar: Self.utc))
        #expect(!QuietHours.isWithin(now: Self.makeDate(hour: 7, minute: 0),  startMinutes: start, endMinutes: end, calendar: Self.utc))
        #expect(!QuietHours.isWithin(now: Self.makeDate(hour: 12, minute: 0), startMinutes: start, endMinutes: end, calendar: Self.utc))
    }

    @Test func equalStartEndIsEmptyWindow() {
        let now = Self.makeDate(hour: 12, minute: 0)
        #expect(!QuietHours.isWithin(now: now, startMinutes: 12*60, endMinutes: 12*60, calendar: Self.utc))
    }

    @Test func minuteOfDayBoundaries() {
        #expect(QuietHours.minuteOfDay(Self.makeDate(hour: 0,  minute: 0),  calendar: Self.utc) == 0)
        #expect(QuietHours.minuteOfDay(Self.makeDate(hour: 23, minute: 59), calendar: Self.utc) == 23*60 + 59)
    }
}
