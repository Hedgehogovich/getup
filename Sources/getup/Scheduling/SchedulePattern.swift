import Foundation

enum SchedulePattern: Equatable {
    case hourly([Int])
    case everyTwoHours(Int)

    static func make(intervalMinutes: Int, anchorMinute: Int) -> SchedulePattern {
        let interval = max(1, intervalMinutes)
        let anchor = max(0, min(59, anchorMinute))
        guard interval <= 60 else { return .everyTwoHours(anchor) }
        let phase = anchor % interval
        return .hourly(Array(stride(from: phase, to: 60, by: interval)))
    }
}
