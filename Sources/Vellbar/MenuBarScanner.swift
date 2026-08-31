import AppKit
import ApplicationServices
import CoreGraphics
import VellbarCore

/// Finds the menu bar items.
///
/// Positions and window IDs come from the window list, which always works and
/// needs no permission. Names are attempted through ControlCenter's
/// Accessibility tree and are usually unavailable — which is fine, because with
/// Screen Recording granted the captured icon identifies the item far better
/// than a name would.
@MainActor
enum MenuBarScanner {

    static func scan() -> [MenuBarItem] {
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return [] }

        let items: [MenuBarItem] = list.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == statusLayer,
                  let raw = info[kCGWindowNumber as String] as? NSNumber,
                  // Non-trapping: a window number outside UInt32 is not ours to
                  // care about, and a trap here would take the app down.
                  let number = UInt32(exactly: raw.int64Value),
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            return MenuBarItem(windowID: number, frame: rect)
        }

        return MenuBarLayout.plausible(items, excluding: ownWindowIDs())
    }

    /// Our own separator and chevron, so Vellbar never lists itself.
    private static func ownWindowIDs() -> Set<UInt32> {
        // `UInt32(exactly:)` rather than `UInt32(_:)`: AppKit hands back
        // sentinel window numbers for off-screen and system-owned windows, and
        // converting one of those traps.
        Set(NSApp.windows.compactMap { UInt32(exactly: $0.windowNumber) })
    }

    /// The strip of screen the menu bar items occupy, in display points.
    static func menuBarStrip(for items: [MenuBarItem]) -> CGRect? {
        guard !items.isEmpty else { return nil }
        return items.dropFirst().reduce(items[0].frame) { $0.union($1.frame) }
    }
}
