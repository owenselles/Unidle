import XCTest
@testable import Unidle

final class ActivityPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Everything switched on and healthy; each test knocks out one input.
    private func policy(
        isEnabled: Bool = true,
        isTrusted: Bool = true,
        scheduleEnabled: Bool = false,
        schedule: WorkSchedule = .default,
        activeUntil: Date? = nil,
        pauseOnLowBattery: Bool = true,
        battery: BatteryState? = nil
    ) -> ActivityPolicy {
        ActivityPolicy(
            isEnabled: isEnabled,
            isTrusted: isTrusted,
            scheduleEnabled: scheduleEnabled,
            schedule: schedule,
            activeUntil: activeUntil,
            pauseOnLowBattery: pauseOnLowBattery,
            battery: battery
        )
    }

    func testRunsWhenEverythingIsSatisfied() {
        XCTAssertEqual(policy().decide(at: now), .run)
    }

    func testDisabledWins() {
        XCTAssertEqual(policy(isEnabled: false, isTrusted: false).decide(at: now), .off)
    }

    func testPermissionOutranksSchedule() {
        let decision = policy(isTrusted: false, scheduleEnabled: true, schedule: WorkSchedule(days: [], startMinutes: 0, endMinutes: 0))
            .decide(at: now)
        XCTAssertEqual(decision, .needsPermission)
    }

    // MARK: - Timed sessions

    func testExpiresOnceDeadlinePasses() {
        XCTAssertEqual(policy(activeUntil: now.addingTimeInterval(-1)).decide(at: now), .expired)
    }

    func testExpiresExactlyAtDeadline() {
        XCTAssertEqual(policy(activeUntil: now).decide(at: now), .expired)
    }

    func testStillRunningBeforeDeadline() {
        XCTAssertEqual(policy(activeUntil: now.addingTimeInterval(60)).decide(at: now), .run)
    }

    func testExpiryOutranksLowBattery() {
        let decision = policy(
            activeUntil: now.addingTimeInterval(-1),
            battery: BatteryState(percentage: 5, isPluggedIn: false)
        ).decide(at: now)
        XCTAssertEqual(decision, .expired)
    }

    // MARK: - Low battery

    func testPausesOnLowBattery() {
        let decision = policy(battery: BatteryState(percentage: 15, isPluggedIn: false)).decide(at: now)
        XCTAssertEqual(decision, .lowBattery)
    }

    func testPausesExactlyAtThreshold() {
        let decision = policy(battery: BatteryState(percentage: ActivityPolicy.lowBatteryThreshold, isPluggedIn: false))
            .decide(at: now)
        XCTAssertEqual(decision, .lowBattery)
    }

    func testKeepsRunningJustAboveThreshold() {
        let decision = policy(battery: BatteryState(percentage: ActivityPolicy.lowBatteryThreshold + 1, isPluggedIn: false))
            .decide(at: now)
        XCTAssertEqual(decision, .run)
    }

    func testIgnoresLowBatteryWhilePluggedIn() {
        XCTAssertEqual(policy(battery: BatteryState(percentage: 5, isPluggedIn: true)).decide(at: now), .run)
    }

    func testRespectsThePreferenceBeingOff() {
        let decision = policy(pauseOnLowBattery: false, battery: BatteryState(percentage: 5, isPluggedIn: false))
            .decide(at: now)
        XCTAssertEqual(decision, .run)
    }

    /// Desktop Macs report no battery at all and must never be paused.
    func testNoBatteryNeverPauses() {
        XCTAssertEqual(policy(battery: nil).decide(at: now), .run)
    }

    // MARK: - Schedule

    func testOutsideScheduleIsPaused() {
        let never = WorkSchedule(days: [], startMinutes: 0, endMinutes: 24 * 60)
        XCTAssertEqual(policy(scheduleEnabled: true, schedule: never).decide(at: now), .outsideSchedule)
    }

    func testScheduleIgnoredWhenDisabled() {
        let never = WorkSchedule(days: [], startMinutes: 0, endMinutes: 24 * 60)
        XCTAssertEqual(policy(scheduleEnabled: false, schedule: never).decide(at: now), .run)
    }
}
