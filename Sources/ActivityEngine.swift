import ApplicationServices
import Combine
import CoreGraphics
import Foundation

/// Keeps the system's input-idle clock below a threshold by posting a
/// zero-delta mouse move. Presence-aware apps (Slack, Teams, Discord) read that
/// same clock via `CGEventSourceSecondsSinceLastEventType`, so resetting it is
/// what actually keeps their status on Active — sleep assertions do not.
///
/// The event carries no displacement, so the cursor never visibly moves and no
/// keystroke can leak into whatever app has focus.
@MainActor
final class ActivityEngine: ObservableObject {
    static let shared = ActivityEngine(preferences: .shared)

    @Published private(set) var decision: ActivityPolicy.Decision = .off
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    @Published private(set) var systemIdle: TimeInterval = 0
    @Published private(set) var lastNudge: Date?
    @Published private(set) var battery: BatteryState?

    /// True while the pointer is tracing its path, so a tick that lands
    /// mid-movement doesn't start a second one on top of it.
    @Published private(set) var isMoving = false

    /// Time left in the current timed session, or nil when running open-ended.
    var remainingSession: TimeInterval? {
        guard let activeUntil = preferences.activeUntil else { return nil }
        return max(0, activeUntil.timeIntervalSinceNow)
    }

    private let preferences: Preferences
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private static let tickInterval: TimeInterval = 5

    init(preferences: Preferences) {
        self.preferences = preferences
        preferences.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.tick() }
            }
            .store(in: &cancellables)
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    /// Opens the system prompt that adds us to Privacy & Security › Accessibility.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        decision = policy().decide(at: Date())
    }

    private func tick() {
        isTrusted = AXIsProcessTrusted()
        systemIdle = Self.currentSystemIdle()
        battery = BatteryMonitor.current()
        decision = policy().decide(at: Date())

        // A finished timed session switches the app off, so the menu reflects
        // what actually happened instead of silently doing nothing.
        if decision == .expired {
            preferences.activeUntil = nil
            preferences.isEnabled = false
            decision = policy().decide(at: Date())
            return
        }

        guard decision == .run, !isMoving, systemIdle >= preferences.idleThreshold else { return }
        postSyntheticInput()
        systemIdle = Self.currentSystemIdle()
    }

    private func policy() -> ActivityPolicy {
        ActivityPolicy(
            isEnabled: preferences.isEnabled,
            isTrusted: isTrusted,
            scheduleEnabled: preferences.scheduleEnabled,
            schedule: preferences.schedule,
            activeUntil: preferences.activeUntil,
            pauseOnLowBattery: preferences.pauseOnLowBattery,
            battery: battery
        )
    }

    private func postSyntheticInput() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let origin = CGEvent(source: nil)?.location
        else { return }

        let movement = PointerMovement(amplitude: CGFloat(preferences.pointerAmplitude))
        let path = movement.path(from: origin)
        lastNudge = Date()

        guard path.count > 1 else {
            post(path[0], source: source)
            return
        }

        // Walk the path over roughly a third of a second. Awaiting on the main
        // actor yields rather than blocking, so the menu stays responsive.
        isMoving = true
        Task { @MainActor in
            for point in path {
                post(point, source: source)
                try? await Task.sleep(nanoseconds: 12_000_000)
            }
            isMoving = false
        }
    }

    private func post(_ point: CGPoint, source: CGEventSource) {
        CGEvent(mouseEventSource: source,
                mouseType: .mouseMoved,
                mouseCursorPosition: point,
                mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    /// Seconds since the last input event of any kind, counting both hardware
    /// and synthetic events — the exact value Electron's `getSystemIdleTime`
    /// reports to Slack, Teams and Discord.
    static func currentSystemIdle() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
