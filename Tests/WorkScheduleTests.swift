import XCTest
@testable import Unidle

final class WorkScheduleTests: XCTestCase {

    /// Fixed calendar and timezone: the schedule compares wall-clock minutes,
    /// so tests must not depend on wherever the machine happens to be.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    /// Guards the fixture itself: August 2026 must line up the way the rest of
    /// these tests assume, with Calendar's Sunday-is-1 numbering.
    func testFixtureWeekdayNumbering() {
        XCTAssertEqual(calendar.component(.weekday, from: date(9, 12, 0)), 1, "9 Aug 2026 should be Sunday")
        XCTAssertEqual(calendar.component(.weekday, from: date(10, 12, 0)), 2, "10 Aug 2026 should be Monday")
        XCTAssertEqual(calendar.component(.weekday, from: date(15, 12, 0)), 7, "15 Aug 2026 should be Saturday")
    }

    // MARK: - Ordinary windows

    func testInsideWindowOnSelectedDay() {
        XCTAssertTrue(WorkSchedule.default.contains(date(10, 10, 0), calendar: calendar))
    }

    func testStartBoundaryIsInclusive() {
        XCTAssertTrue(WorkSchedule.default.contains(date(10, 9, 0), calendar: calendar))
    }

    func testEndBoundaryIsExclusive() {
        XCTAssertFalse(WorkSchedule.default.contains(date(10, 17, 0), calendar: calendar))
    }

    func testJustBeforeStart() {
        XCTAssertFalse(WorkSchedule.default.contains(date(10, 8, 59), calendar: calendar))
    }

    func testWeekendIsExcluded() {
        XCTAssertFalse(WorkSchedule.default.contains(date(15, 10, 0), calendar: calendar))
    }

    /// Deselecting every day should mean "never", not "always".
    func testEmptyDaySetIsNeverActive() {
        let schedule = WorkSchedule(days: [], startMinutes: 0, endMinutes: 24 * 60)
        XCTAssertFalse(schedule.contains(date(10, 12, 0), calendar: calendar))
    }

    // MARK: - Overnight windows

    private let mondayNight = WorkSchedule(days: [2], startMinutes: 22 * 60, endMinutes: 6 * 60)

    func testOvernightIsDetected() {
        XCTAssertTrue(mondayNight.isOvernight)
        XCTAssertFalse(WorkSchedule.default.isOvernight)
    }

    func testEqualStartAndEndCountsAsOvernight() {
        let schedule = WorkSchedule(days: [2], startMinutes: 9 * 60, endMinutes: 9 * 60)
        XCTAssertTrue(schedule.isOvernight)
    }

    func testOvernightLateOnSelectedDay() {
        XCTAssertTrue(mondayNight.contains(date(10, 23, 0), calendar: calendar))
    }

    func testOvernightSpillsIntoNextMorning() {
        // Tuesday 03:00 is still inside Monday night's window.
        XCTAssertTrue(mondayNight.contains(date(11, 3, 0), calendar: calendar))
    }

    func testOvernightStopsAtEndTime() {
        XCTAssertFalse(mondayNight.contains(date(11, 7, 0), calendar: calendar))
    }

    func testOvernightBeforeStartIsInactive() {
        XCTAssertFalse(mondayNight.contains(date(10, 21, 0), calendar: calendar))
    }

    func testOvernightDoesNotLeakIntoUnselectedDay() {
        // Wednesday 03:00 would need Tuesday selected, and it isn't.
        XCTAssertFalse(mondayNight.contains(date(12, 3, 0), calendar: calendar))
    }

    /// The previous-day lookup has to wrap from Sunday (1) back to Saturday (7).
    /// Only a Sunday morning exercises that wrap — on any other day plain
    /// subtraction would give the same answer and hide a broken wrap.
    func testOvernightWrapsFromSundayBackToSaturday() {
        let saturdayNight = WorkSchedule(days: [7], startMinutes: 22 * 60, endMinutes: 6 * 60)
        XCTAssertTrue(saturdayNight.contains(date(9, 3, 0), calendar: calendar), "Sunday 03:00 follows Saturday night")
        XCTAssertTrue(saturdayNight.contains(date(16, 3, 0), calendar: calendar), "The following Sunday morning also follows a Saturday")
        XCTAssertFalse(saturdayNight.contains(date(11, 3, 0), calendar: calendar), "Tuesday 03:00 follows a Monday, which isn't selected")
    }

    func testOvernightFromSundayIntoMonday() {
        let sundayNight = WorkSchedule(days: [1], startMinutes: 22 * 60, endMinutes: 6 * 60)
        XCTAssertTrue(sundayNight.contains(date(10, 3, 0), calendar: calendar), "Monday 03:00 follows Sunday night")
        XCTAssertFalse(sundayNight.contains(date(9, 3, 0), calendar: calendar), "Sunday 03:00 would need Saturday selected")
    }

    // MARK: - Summary

    func testWeekdaysSummary() {
        XCTAssertTrue(WorkSchedule.default.summary.hasPrefix("Weekdays"))
    }

    func testEmptySummary() {
        XCTAssertEqual(WorkSchedule(days: [], startMinutes: 0, endMinutes: 60).summary, "No days selected")
    }
}
