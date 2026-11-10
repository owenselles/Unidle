import AppKit
import SwiftUI

/// A plain `NSWindow` rather than a SwiftUI `Window` scene: this is an
/// `LSUIElement` app with no Dock icon, and AppKit gives us reliable control
/// over showing and focusing a window from a menu bar-only process.
@MainActor
final class OnboardingWindow {
    static let shared = OnboardingWindow()

    private var window: NSWindow?

    func showIfNeeded(preferences: Preferences, engine: ActivityEngine) {
        guard !preferences.hasCompletedOnboarding || !engine.isTrusted else { return }
        show(preferences: preferences, engine: engine)
    }

    func show(preferences: Preferences, engine: ActivityEngine) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(engine: engine) { [weak self] in
            preferences.hasCompletedOnboarding = true
            self?.close()
        }

        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to Unidle"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func close() {
        window?.close()
        window = nil
    }
}
