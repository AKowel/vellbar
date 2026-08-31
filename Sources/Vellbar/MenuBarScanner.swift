import AppKit
import ApplicationServices
import CoreGraphics
import VellbarCore

/// Finds the menu bar extras.
///
/// This is harder than it looks. Modern macOS renders **every** status item —
/// third-party ones included — inside the ControlCenter process, so the window
/// list attributes them all to ControlCenter and can tell you where they are
/// but never whose they are. That is precisely why Bartender and Ice ask for
/// Screen Recording: capturing pixels is the only way to see the icons.
///
/// Vellbar takes a cheaper route. ControlCenter exposes its extras through the
/// Accessibility API, where each item usually carries a title or description
/// naming its owner. That needs only the permission Vellbar already asks for.
/// Where a name is unavailable the item still appears, just unnamed — better
/// than pretending it isn't there.
@MainActor
enum MenuBarScanner {

    /// Positions and count, from the window list. Always works, names nothing.
    static func positions() -> [CGRect] {
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return [] }

        return list.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == statusLayer,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            return rect
        }.sorted { $0.minX > $1.minX }
    }

    /// Named items via ControlCenter's Accessibility tree. Empty when the
    /// permission is missing or the attribute is unavailable.
    static func scan() -> [MenuBarItem] {
        guard AccessibilityPermission.isTrusted,
              let controlCenter = NSWorkspace.shared.runningApplications.first(where: {
                  $0.bundleIdentifier == "com.apple.controlcenter"
              })
        else { return [] }

        let app = AXUIElementCreateApplication(controlCenter.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.5)

        guard let extras = element(app, "AXExtrasMenuBar"),
              let children = value(extras, kAXChildrenAttribute as String) as? [AXUIElement]
        else { return [] }

        return children.enumerated().compactMap { index, child in
            let frame = frame(of: child) ?? .zero
            let name = [
                value(child, kAXTitleAttribute as String) as? String,
                value(child, kAXDescriptionAttribute as String) as? String,
                value(child, "AXIdentifier") as? String,
            ]
            .compactMap { $0 }
            .first { !$0.isEmpty }

            return MenuBarItem(id: "extra-\(index)",
                               ownerPID: controlCenter.processIdentifier,
                               ownerName: name ?? "Menu bar item \(index + 1)",
                               frame: frame)
        }
        .sorted { $0.frame.minX > $1.frame.minX }
    }

    /// True when Accessibility gave us real names — used to tell the user
    /// plainly whether the list is informative or just a count.
    static func canIdentifyItems() -> Bool {
        !scan().isEmpty
    }

    // MARK: AX plumbing

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success
        else { return nil }
        return result
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = value(element, attribute),
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let posRaw = value(element, kAXPositionAttribute as String),
              CFGetTypeID(posRaw) == AXValueGetTypeID(),
              let sizeRaw = value(element, kAXSizeAttribute as String),
              CFGetTypeID(sizeRaw) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posRaw as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeRaw as! AXValue, .cgSize, &size)
        return CGRect(origin: origin, size: size)
    }
}
