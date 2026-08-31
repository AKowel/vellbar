import AppKit
import CoreGraphics

/// Screen Recording is the only way to see menu bar icons.
///
/// Not a choice — macOS renders every status item inside ControlCenter and
/// exposes no API for their images. Reading the pixels is the only route, which
/// is why every menu bar manager that shows real icons asks for this.
///
/// Vellbar captures a single strip of the menu bar and nothing else. It never
/// records continuously, never writes an image to disk, and never sends one
/// anywhere.
@MainActor
enum ScreenRecordingPermission {

    static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Triggers the system prompt. Returns immediately; the grant only takes
    /// effect after the app is relaunched, which macOS enforces.
    @discardableResult
    static func request() -> Bool { CGRequestScreenCaptureAccess() }

    static func openSystemSettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}
