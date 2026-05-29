import Testing
@testable import getup

@Suite("SchedulePattern — schedule-summary math")
struct SchedulePatternTests {
    @Test func interval5FillsEveryFifthMinute() {
        #expect(SchedulePattern.make(intervalMinutes: 5, anchorMinute: 50)
            == .hourly([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]))
    }

    @Test func interval10PhaseZero() {
        #expect(SchedulePattern.make(intervalMinutes: 10, anchorMinute: 30) == .hourly([0, 10, 20, 30, 40, 50]))
    }

    @Test func interval10PhaseFive() {
        #expect(SchedulePattern.make(intervalMinutes: 10, anchorMinute: 45) == .hourly([5, 15, 25, 35, 45, 55]))
    }

    @Test func interval15PhaseFive() {
        #expect(SchedulePattern.make(intervalMinutes: 15, anchorMinute: 50) == .hourly([5, 20, 35, 50]))
    }

    @Test func interval20PhaseTen() {
        #expect(SchedulePattern.make(intervalMinutes: 20, anchorMinute: 50) == .hourly([10, 30, 50]))
    }

    @Test func interval30PhaseFifteen() {
        #expect(SchedulePattern.make(intervalMinutes: 30, anchorMinute: 15) == .hourly([15, 45]))
    }

    @Test func interval60SingleRingAtAnchor() {
        #expect(SchedulePattern.make(intervalMinutes: 60, anchorMinute: 50) == .hourly([50]))
    }

    @Test func interval120EveryTwoHoursAtAnchor() {
        #expect(SchedulePattern.make(intervalMinutes: 120, anchorMinute: 50) == .everyTwoHours(50))
    }

    @Test func clampsAnchorAbove59() {
        #expect(SchedulePattern.make(intervalMinutes: 60, anchorMinute: 99) == .hourly([59]))
    }

    @Test func clampsNegativeAnchorToZero() {
        #expect(SchedulePattern.make(intervalMinutes: 30, anchorMinute: -5) == .hourly([0, 30]))
    }

    @Test func clampsZeroIntervalToOne() {
        #expect(SchedulePattern.make(intervalMinutes: 0, anchorMinute: 0) == .hourly(Array(0...59)))
    }
}
