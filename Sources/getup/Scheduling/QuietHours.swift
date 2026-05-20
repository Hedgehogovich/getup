import Foundation

enum QuietHours {
    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Inclusive of `start`, exclusive of `end`. Handles ranges that cross midnight
    /// (start > end, e.g. 22:00 → 07:00). `start == end` is an empty window.
    static func isWithin(now: Date, startMinutes start: Int, endMinutes end: Int, calendar: Calendar = .current) -> Bool {
        guard start != end else { return false }
        let m = minuteOfDay(now, calendar: calendar)
        return start < end ? (m >= start && m < end) : (m >= start || m < end)
    }
}
