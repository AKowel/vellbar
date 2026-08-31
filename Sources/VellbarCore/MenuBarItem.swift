import CoreGraphics
import Foundation

/// One icon in the menu bar, as seen from outside the app that owns it.
///
/// macOS exposes a status item's **position and owner** through the window
/// list, but never its rendered image — there is no API to read another app's
/// menu bar icon. So Vellbar identifies items by who owns them and shows that
/// application's own icon instead.
public struct MenuBarItem: Sendable, Equatable, Identifiable {
    public let id: String
    public let ownerPID: Int32
    public let ownerName: String
    public let frame: CGRect

    public init(id: String, ownerPID: Int32, ownerName: String, frame: CGRect) {
        self.id = id
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.frame = frame
    }

    /// Where a synthesised click should land to activate this item.
    public var clickPoint: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

/// Several items belonging to one application.
///
/// Apps commonly own more than one status item, and since their glyphs are
/// unreadable from outside they would appear as identical rows. Grouping keeps
/// the list honest: one entry per app, with a count when it owns several.
public struct MenuBarGroup: Sendable, Equatable, Identifiable {
    public let ownerPID: Int32
    public let ownerName: String
    public let items: [MenuBarItem]

    public var id: Int32 { ownerPID }
    public var count: Int { items.count }

    /// The leftmost item, which is the one a single click should target.
    public var primary: MenuBarItem? {
        items.min { $0.frame.minX < $1.frame.minX }
    }

    public init(ownerPID: Int32, ownerName: String, items: [MenuBarItem]) {
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.items = items
    }
}

public enum MenuBarLayout {

    /// Owners whose items are not ours to manage. The clock, Control Center and
    /// input menus are drawn by the system and cannot be hidden or clicked
    /// through the way third-party items can.
    public static let systemOwners: Set<String> = [
        "Control Center", "ControlCenter",
        "SystemUIServer",
        "TextInputMenuAgent", "TextInputSwitcher",
        "Spotlight",
        "NotificationCenter",
        "Window Server", "WindowServer",
    ]

    public static func isSystemOwned(_ item: MenuBarItem) -> Bool {
        systemOwners.contains(item.ownerName)
    }

    /// Menu bar items read right to left: the rightmost is closest to the
    /// clock. Sorting descending by x gives the order a person sees.
    public static func inVisualOrder(_ items: [MenuBarItem]) -> [MenuBarItem] {
        items.sorted { $0.frame.minX > $1.frame.minX }
    }

    /// Third-party items only, in visual order, excluding our own.
    public static func manageable(_ items: [MenuBarItem],
                                  excludingPID ownPID: Int32) -> [MenuBarItem] {
        inVisualOrder(items.filter { $0.ownerPID != ownPID && !isSystemOwned($0) })
    }

    /// One entry per owning application, ordered by each app's rightmost item
    /// so the list matches what the eye sees.
    public static func grouped(_ items: [MenuBarItem]) -> [MenuBarGroup] {
        var byOwner: [Int32: [MenuBarItem]] = [:]
        for item in items { byOwner[item.ownerPID, default: []].append(item) }

        return byOwner
            .map { pid, group in
                MenuBarGroup(ownerPID: pid,
                             ownerName: group[0].ownerName,
                             items: inVisualOrder(group))
            }
            .sorted { a, b in
                let ax = a.items.first?.frame.minX ?? 0
                let bx = b.items.first?.frame.minX ?? 0
                return ax > bx
            }
    }

    /// Items that fall to the left of the separator, and are therefore the ones
    /// pushed off-screen when Vellbar collapses.
    public static func hidden(_ items: [MenuBarItem],
                              leftOfSeparatorX x: CGFloat) -> [MenuBarItem] {
        inVisualOrder(items.filter { $0.frame.maxX <= x })
    }

    /// Items that stay on show.
    public static func alwaysVisible(_ items: [MenuBarItem],
                                     leftOfSeparatorX x: CGFloat) -> [MenuBarItem] {
        inVisualOrder(items.filter { $0.frame.maxX > x })
    }
}
