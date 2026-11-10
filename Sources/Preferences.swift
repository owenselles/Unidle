import Combine
import Foundation

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let isEnabled = "isEnabled"
        static let idleThreshold = "idleThreshold"
        static let scheduleEnabled = "scheduleEnabled"
        static let scheduleDays = "scheduleDays"
        static let scheduleStart = "scheduleStart"
        static let scheduleEnd = "scheduleEnd"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let pauseOnLowBattery = "pauseOnLowBattery"
        static let activeUntil = "activeUntil"
        static let pointerAmplitude = "pointerAmplitude"
    }

    /// Durations offered in the menu. `nil` means run until switched off.
    static let sessionDurations: [TimeInterval?] = [nil, 30 * 60, 60 * 60, 2 * 60 * 60]

    /// How long the Mac may sit without input before we step in. Anything well
    /// under five minutes keeps Slack, Teams and Discord from flipping to Away.
    static let idleThresholdOptions: [TimeInterval] = [30, 60, 120, 240]

    private let defaults: UserDefaults

    @Published var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Key.isEnabled) } }
    @Published var idleThreshold: TimeInterval { didSet { defaults.set(idleThreshold, forKey: Key.idleThreshold) } }
    @Published var scheduleEnabled: Bool { didSet { defaults.set(scheduleEnabled, forKey: Key.scheduleEnabled) } }
    @Published var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) } }
    @Published var pauseOnLowBattery: Bool { didSet { defaults.set(pauseOnLowBattery, forKey: Key.pauseOnLowBattery) } }

    /// How far the pointer travels. Visible by default, so the movement can be
    /// followed by someone using the cursor as a visual anchor.
    @Published var pointerAmplitude: Double { didSet { defaults.set(pointerAmplitude, forKey: Key.pointerAmplitude) } }

    /// When the current timed session ends. Persisted so quitting and
    /// relaunching inside the window doesn't silently extend it forever.
    @Published var activeUntil: Date? {
        didSet {
            if let activeUntil {
                defaults.set(activeUntil.timeIntervalSinceReferenceDate, forKey: Key.activeUntil)
            } else {
                defaults.removeObject(forKey: Key.activeUntil)
            }
        }
    }
    @Published var schedule: WorkSchedule {
        didSet {
            defaults.set(Self.mask(from: schedule.days), forKey: Key.scheduleDays)
            defaults.set(schedule.startMinutes, forKey: Key.scheduleStart)
            defaults.set(schedule.endMinutes, forKey: Key.scheduleEnd)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.idleThreshold: 60.0,
            Key.scheduleDays: Self.mask(from: WorkSchedule.default.days),
            Key.scheduleStart: WorkSchedule.default.startMinutes,
            Key.scheduleEnd: WorkSchedule.default.endMinutes,
            Key.pauseOnLowBattery: true,
            Key.pointerAmplitude: 64.0,
        ])
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        idleThreshold = defaults.double(forKey: Key.idleThreshold)
        scheduleEnabled = defaults.bool(forKey: Key.scheduleEnabled)
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        pauseOnLowBattery = defaults.bool(forKey: Key.pauseOnLowBattery)
        pointerAmplitude = defaults.double(forKey: Key.pointerAmplitude)
        let storedExpiry = defaults.object(forKey: Key.activeUntil) as? Double
        activeUntil = storedExpiry.map { Date(timeIntervalSinceReferenceDate: $0) }
        schedule = WorkSchedule(
            days: Self.days(from: defaults.integer(forKey: Key.scheduleDays)),
            startMinutes: defaults.integer(forKey: Key.scheduleStart),
            endMinutes: defaults.integer(forKey: Key.scheduleEnd)
        )
    }

    private static func mask(from days: Set<Int>) -> Int {
        days.reduce(0) { $0 | (1 << $1) }
    }

    private static func days(from mask: Int) -> Set<Int> {
        Set((1...7).filter { mask & (1 << $0) != 0 })
    }
}
