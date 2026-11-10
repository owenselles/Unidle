import SwiftUI

struct MenuContent: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var engine: ActivityEngine

    var body: some View {
        Text(statusLine)

        if engine.decision == .needsPermission {
            Button("Set Up Accessibility Access…") {
                OnboardingWindow.shared.show(preferences: preferences, engine: engine)
            }
        }

        Divider()

        Toggle("Keep Me Active", isOn: $preferences.isEnabled)

        Menu("Keep Active For") {
            ForEach(Preferences.sessionDurations, id: \.self) { duration in
                Button(Self.durationLabel(duration)) { start(duration) }
            }
        }

        Toggle("Only During Work Hours", isOn: $preferences.scheduleEnabled)
            .disabled(!preferences.isEnabled)

        if preferences.scheduleEnabled {
            Text(preferences.schedule.summary)
        }

        Divider()

        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",", modifiers: .command)
        Button("Quit Unidle") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    /// Picking a duration is also a request to switch on, so the user doesn't
    /// have to toggle two things to start a session.
    private func start(_ duration: TimeInterval?) {
        preferences.activeUntil = duration.map { Date().addingTimeInterval($0) }
        preferences.isEnabled = true
    }

    private var statusLine: String {
        switch engine.decision {
        case .off: return "Off"
        case .needsPermission: return "Needs Accessibility access"
        case .expired: return "Session finished"
        case .lowBattery: return "Paused — battery low"
        case .outsideSchedule: return "Paused — outside work hours"
        case .run:
            if let remaining = engine.remainingSession {
                return "Active — \(Self.remainingLabel(remaining)) left"
            }
            return "Active — idle \(Int(engine.systemIdle))s"
        }
    }

    private static func durationLabel(_ duration: TimeInterval?) -> String {
        guard let duration else { return "Until I Turn It Off" }
        let minutes = Int(duration / 60)
        return minutes < 60 ? "\(minutes) Minutes" : "\(minutes / 60) Hour\(minutes >= 120 ? "s" : "")"
    }

    private static func remainingLabel(_ remaining: TimeInterval) -> String {
        let minutes = Int(remaining / 60)
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return minutes >= 1 ? "\(minutes)m" : "under a minute"
    }
}
