import Testing
import CoreGraphics
import Foundation
@testable import VellbarCore

private func item(_ id: String, pid: Int32, owner: String, x: CGFloat, w: CGFloat = 24) -> MenuBarItem {
    MenuBarItem(id: id, ownerPID: pid, ownerName: owner,
                frame: CGRect(x: x, y: 0, width: w, height: 24))
}

@Suite("Menu bar ordering")
struct OrderingTests {

    @Test("visual order runs right to left, the way the eye reads the bar")
    func visualOrder() {
        let items = [item("a", pid: 1, owner: "A", x: 100),
                     item("c", pid: 3, owner: "C", x: 300),
                     item("b", pid: 2, owner: "B", x: 200)]
        #expect(MenuBarLayout.inVisualOrder(items).map(\.id) == ["c", "b", "a"])
    }

    @Test("system-drawn items are left alone")
    func systemItemsExcluded() {
        let items = [item("clock", pid: 9, owner: "Control Center", x: 400),
                     item("mine", pid: 1, owner: "Dropbox", x: 200)]
        let managed = MenuBarLayout.manageable(items, excludingPID: 77)
        #expect(managed.map(\.id) == ["mine"])
    }

    @Test("our own items never appear in our own list")
    func ownItemsExcluded() {
        let items = [item("ours", pid: 77, owner: "Vellbar", x: 400),
                     item("theirs", pid: 1, owner: "Dropbox", x: 200)]
        #expect(MenuBarLayout.manageable(items, excludingPID: 77).map(\.id) == ["theirs"])
    }
}

@Suite("Grouping by application")
struct GroupingTests {

    @Test("an app owning several items becomes one entry with a count")
    func multipleItemsCollapse() {
        let items = [item("d1", pid: 5, owner: "Docker", x: 100),
                     item("d2", pid: 5, owner: "Docker", x: 140),
                     item("s1", pid: 6, owner: "Slack", x: 300)]
        let groups = MenuBarLayout.grouped(items)
        #expect(groups.count == 2)
        let docker = groups.first { $0.ownerName == "Docker" }
        #expect(docker?.count == 2)
        #expect(groups.first { $0.ownerName == "Slack" }?.count == 1)
    }

    @Test("groups are ordered by their rightmost item, matching the bar")
    func groupOrder() {
        let items = [item("a", pid: 1, owner: "Alpha", x: 100),
                     item("z", pid: 2, owner: "Zulu", x: 500)]
        #expect(MenuBarLayout.grouped(items).map(\.ownerName) == ["Zulu", "Alpha"])
    }

    @Test("a group's primary item is its leftmost, which is what a click targets")
    func primaryItem() {
        let group = MenuBarGroup(ownerPID: 5, ownerName: "Docker",
                                 items: [item("right", pid: 5, owner: "Docker", x: 200),
                                         item("left", pid: 5, owner: "Docker", x: 100)])
        #expect(group.primary?.id == "left")
    }

    @Test("an empty group has no primary rather than crashing")
    func emptyGroup() {
        #expect(MenuBarGroup(ownerPID: 1, ownerName: "None", items: []).primary == nil)
    }
}

@Suite("Hiding")
struct HidingTests {

    let items = [
        item("far-left",  pid: 1, owner: "A", x: 100),
        item("mid",       pid: 2, owner: "B", x: 200),
        item("near-sep",  pid: 3, owner: "C", x: 300),
        item("right-of",  pid: 4, owner: "D", x: 400),
    ]

    @Test("everything left of the separator is what gets hidden")
    func hiddenSet() {
        // Separator sits at x = 340, so items ending at or before it hide.
        #expect(MenuBarLayout.hidden(items, leftOfSeparatorX: 340).map(\.id)
                == ["near-sep", "mid", "far-left"])
    }

    @Test("everything right of the separator stays on show")
    func visibleSet() {
        #expect(MenuBarLayout.alwaysVisible(items, leftOfSeparatorX: 340).map(\.id)
                == ["right-of"])
    }

    @Test("hidden and visible together account for every item, with no overlap")
    func partitionIsComplete() {
        for x in stride(from: CGFloat(0), through: 600, by: 50) {
            let hidden = MenuBarLayout.hidden(items, leftOfSeparatorX: x)
            let visible = MenuBarLayout.alwaysVisible(items, leftOfSeparatorX: x)
            #expect(hidden.count + visible.count == items.count, "lost an item at x=\(x)")
            #expect(Set(hidden.map(\.id)).isDisjoint(with: Set(visible.map(\.id))),
                    "an item was both hidden and visible at x=\(x)")
        }
    }

    @Test("a separator at the far left hides nothing")
    func separatorAtEdge() {
        #expect(MenuBarLayout.hidden(items, leftOfSeparatorX: 0).isEmpty)
        #expect(MenuBarLayout.alwaysVisible(items, leftOfSeparatorX: 0).count == 4)
    }
}

@Suite("Click targeting")
struct ClickTests {
    @Test("the click point is the centre of the item")
    func clickPoint() {
        let it = MenuBarItem(id: "x", ownerPID: 1, ownerName: "A",
                             frame: CGRect(x: 100, y: 0, width: 30, height: 24))
        #expect(it.clickPoint == CGPoint(x: 115, y: 12))
    }
}
