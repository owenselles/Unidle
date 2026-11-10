import Foundation

struct BatteryState: Equatable {
    var percentage: Int
    var isPluggedIn: Bool
}

/// Decides whether Unidle should be signalling activity right now.
///
/// Deliberately a pure value type with no timers, no system calls, and no
/// stored state: every rule below is exercised directly in the tests, which is
/// where the schedule's overnight and week-boundary behaviour gets pinned down.
struct ActivityPolicy {
    enum Decision: Equatable {
        case off
        case needsPermission
        case expired
        case lowBattery
        case outsideSchedule
        case run
    }

    /// Below this charge, and running on battery, Unidle stands down.
    static let lowBatteryThreshold = 20

    var isEnabled: Bool
    var isTrusted: Bool
    var scheduleEnabled: Bool
    var schedule: WorkSchedule
    var activeUntil: Date?
    var pauseOnLowBattery: Bool
    var battery: BatteryState?

    func decide(at date: Date, calendar: Calendar = .current) -> Decision {
        guard isEnabled else { return .off }
        guard isTrusted else { return .needsPermission }

        if let activeUntil, date >= activeUntil { return .expired }

        if pauseOnLowBattery, let battery,
           !battery.isPluggedIn, battery.percentage <= Self.lowBatteryThreshold {
            return .lowBattery
        }

        if scheduleEnabled, !schedule.contains(date, calendar: calendar) {
            return .outsideSchedule
        }

        return .run
    }
}
