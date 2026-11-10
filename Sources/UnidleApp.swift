import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        OnboardingWindow.shared.showIfNeeded(preferences: .shared, engine: .shared)
    }

    /// The menu bar item is the app; closing Settings or the welcome window
    /// must not take the whole thing down with it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct UnidleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var preferences = Preferences.shared
    @StateObject private var engine = ActivityEngine.shared
    @StateObject private var loginItem = LoginItem.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(preferences: preferences, engine: engine)
        } label: {
            Image(systemName: engine.decision == .run ? "cursorarrow.motionlines" : "cursorarrow")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(preferences: preferences, engine: engine, loginItem: loginItem)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
    }

    init() {
        ActivityEngine.shared.start()
    }
}
