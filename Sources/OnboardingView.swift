import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var engine: ActivityEngine
    var onFinish: () -> Void

    private let isSandboxed = AppEnvironment.isSandboxed

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Divider()

            if engine.isTrusted {
                grantedState
            } else {
                instructions
                actionButtons
                waitingIndicator
            }
        }
        .padding(28)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Unidle").font(.title2).bold()
                Text("Unidle moves the pointer for you at an interval you choose. It traces a small circle and returns the cursor exactly where it started, so the movement is easy to follow by eye and never leaves your pointer somewhere else.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grant Accessibility access").font(.headline)
            Text("macOS only lets an app move the pointer for you if you allow it under Accessibility. Unidle can't work without it, and it never reads your screen, keystrokes, or any other app.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isSandboxed {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Open Accessibility settings below.", systemImage: "1.circle.fill")
                    Label("Click the + button in the list.", systemImage: "2.circle.fill")
                    Label("Choose Unidle, then switch it on.", systemImage: "3.circle.fill")
                }
                .font(.callout)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            if isSandboxed {
                Button("Open Accessibility Settings") { Self.openAccessibilitySettings() }
                    .buttonStyle(.borderedProminent)
                Button("Reveal Unidle in Finder") { Self.revealSelfInFinder() }
            } else {
                Button("Grant Access…") { engine.requestPermission() }
                    .buttonStyle(.borderedProminent)
                Button("Open Accessibility Settings") { Self.openAccessibilitySettings() }
            }
            Spacer()
            Button("Later", action: onFinish)
        }
    }

    private var waitingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Waiting for access…").foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private var grantedState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("Accessibility access granted").bold()
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            Text("Unidle is running. Use the menu bar icon to turn it off or limit it to your work hours.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Done", action: onFinish).buttonStyle(.borderedProminent)
            }
        }
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func revealSelfInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
}
