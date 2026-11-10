import Foundation

enum AppEnvironment {
    /// Sandboxed builds never receive the Accessibility permission prompt —
    /// macOS suppresses it and no TCC entry is created, verified on macOS 26.6.
    /// Anything that would otherwise call `AXIsProcessTrustedWithOptions` has to
    /// send these users to System Settings instead, or it silently does nothing.
    static let isSandboxed = NSHomeDirectory().contains("/Containers/")
}
