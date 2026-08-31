import AppKit
import ApplicationServices

/// An event tap that can *modify* events needs Accessibility access. Without it
/// Vellscroll can see nothing and change nothing.
@MainActor
enum AccessibilityPermission {

    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func promptIfNeeded() -> Bool {
        // The imported constant is a mutable global and so is rejected under
        // Swift 6 strict concurrency; its value is stable and documented.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSystemSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// The grant arrives asynchronously with no notification to observe, so the
    /// only option is to poll.
    @discardableResult
    static func waitForGrant(pollInterval: Duration = .seconds(1),
                             onGranted: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            while !Task.isCancelled {
                if isTrusted { onGranted(); return }
                try? await Task.sleep(for: pollInterval)
            }
        }
    }
}
