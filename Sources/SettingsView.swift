import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var engine: ActivityEngine
    @ObservedObject var loginItem: LoginItem

    var body: some View {
        Form {
            Section {
                LabeledContent("Accessibility access") {
                    if engine.isTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if AppEnvironment.isSandboxed {
                        // The system prompt would do nothing here, so send the
                        // user somewhere that actually gets them there.
                        Button("Show Me How…") {
                            OnboardingWindow.shared.show(preferences: preferences, engine: engine)
                        }
                    } else {
                        Button("Grant Access…") { engine.requestPermission() }
                    }
                }
            } footer: {
                Text("Unidle needs Accessibility access to move the pointer on your behalf. Without it the app can't do anything.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Step in after", selection: $preferences.idleThreshold) {
                    ForEach(Preferences.idleThresholdOptions, id: \.self) { seconds in
                        Text(Self.thresholdLabel(seconds)).tag(seconds)
                    }
                }
                Picker("Pointer movement", selection: $preferences.pointerAmplitude) {
                    ForEach(PointerMovement.amplitudeOptions, id: \.self) { amplitude in
                        Text(PointerMovement.label(for: amplitude)).tag(Double(amplitude))
                    }
                }
                Toggle("Launch at login", isOn: $loginItem.isEnabled)
                Toggle("Pause below \(ActivityPolicy.lowBatteryThreshold)% battery", isOn: $preferences.pauseOnLowBattery)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unidle traces the pointer in a small circle and returns it to where it started. A visible movement can be followed by anyone using the cursor as a visual anchor; choose None to leave the pointer completely still.")
                    if let error = loginItem.lastError {
                        Text(error).foregroundStyle(.red)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section("Work Hours") {
                Toggle("Only stay active during work hours", isOn: $preferences.scheduleEnabled)
                DayPicker(days: $preferences.schedule.days)
                    .disabled(!preferences.scheduleEnabled)
                DatePicker("From", selection: startBinding, displayedComponents: .hourAndMinute)
                    .disabled(!preferences.scheduleEnabled)
                DatePicker("To", selection: endBinding, displayedComponents: .hourAndMinute)
                    .disabled(!preferences.scheduleEnabled)
                if preferences.schedule.isOvernight {
                    Text("This window runs overnight into the next morning.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: preferences.schedule.startMinutes) },
            set: { preferences.schedule.startMinutes = Self.minutes(from: $0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: preferences.schedule.endMinutes) },
            set: { preferences.schedule.endMinutes = Self.minutes(from: $0) }
        )
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func thresholdLabel(_ seconds: TimeInterval) -> String {
        seconds < 60 ? "\(Int(seconds)) seconds of no input" : "\(Int(seconds / 60)) minute\(seconds >= 120 ? "s" : "") of no input"
    }
}

private struct DayPicker: View {
    @Binding var days: Set<Int>

    var body: some View {
        LabeledContent("Days") {
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { weekday in
                    Toggle(Self.label(weekday), isOn: binding(for: weekday))
                        .toggleStyle(.button)
                }
            }
        }
    }

    private func binding(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: { days.contains(weekday) },
            set: { isOn in
                if isOn { days.insert(weekday) } else { days.remove(weekday) }
            }
        )
    }

    private static func label(_ weekday: Int) -> String {
        String(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
    }
}
