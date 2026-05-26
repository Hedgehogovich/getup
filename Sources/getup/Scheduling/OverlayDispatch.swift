import Foundation

enum OverlayDispatch {
    /// True when a scheduled fire is allowed at `now`. Quiet-hours disabled → always true.
    static func shouldFire(now: Date, settings: Settings, calendar: Calendar = .current) -> Bool {
        guard settings.quietHoursEnabled else { return true }
        return !QuietHours.isWithin(now: now,
                                    startMinutes: settings.quietHoursStartMinutes,
                                    endMinutes: settings.quietHoursEndMinutes,
                                    calendar: calendar)
    }

}

enum SnoozeDecision {
    static let defaultSnoozeMinutes: Int = 10

    static func fireDate(from now: Date, snoozeMinutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(max(1, snoozeMinutes) * 60))
    }
}
