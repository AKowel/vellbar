import AppKit
import ServiceManagement
import VellbarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var separator: SeparatorController?
    private var onboarding: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = SeparatorController()
        controller.buildMenu = { [weak self] in self?.menu() ?? NSMenu() }
        separator = controller

        if !AccessibilityPermission.isTrusted {
            // Hiding works without it. Only naming what's hidden needs it, so
            // this is an invitation rather than a wall.
            showOnboarding()
        }
    }

    // MARK: Menu

    private func menu() -> NSMenu {
        let menu = NSMenu()
        let items = MenuBarScanner.scan()

        if items.isEmpty {
            let count = MenuBarScanner.positions().count
            addReadout(menu, AccessibilityPermission.isTrusted
                ? "Couldn't read item names on this macOS"
                : "Grant Accessibility to list items by name")
            addReadout(menu, "\(count) menu bar item\(count == 1 ? "" : "s") detected")

            if !AccessibilityPermission.isTrusted {
                let grant = NSMenuItem(title: "Grant Access…",
                                       action: #selector(showOnboarding), keyEquivalent: "")
                grant.target = self
                menu.addItem(grant)
            }
        } else {
            addReadout(menu, "Menu bar items")
            for group in MenuBarLayout.grouped(items) {
                let title = group.count > 1
                    ? "\(group.ownerName)  (\(group.count))"
                    : group.ownerName
                let item = NSMenuItem(title: title,
                                      action: #selector(activate(_:)), keyEquivalent: "")
                item.target = self
                if let primary = group.primary {
                    item.representedObject = NSValue(point: primary.clickPoint)
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: separator?.isCollapsed == true ? "Show hidden items" : "Hide items",
            action: #selector(toggleCollapse), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let help = NSMenuItem(title: "How to choose what hides…",
                              action: #selector(showHelp), keyEquivalent: "")
        help.target = self
        menu.addItem(help)

        menu.addItem(.separator())

        let launch = NSMenuItem(title: "Launch at login",
                                action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launch.target = self
        launch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launch)

        let donate = NSMenuItem(title: "Vellbar is free — support it",
                                action: #selector(openDonate), keyEquivalent: "")
        donate.target = self
        menu.addItem(donate)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Vellbar",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    private func addReadout(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    // MARK: Actions

    @objc private func activate(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? NSValue else { return }
        let point = value.pointValue
        // The item may currently be pushed off-screen, so reveal, click, restore.
        separator?.revealing {
            ItemActivator.click(at: CGPoint(x: point.x, y: point.y))
        }
    }

    @objc private func toggleCollapse() {
        guard let separator else { return }
        separator.setCollapsed(!separator.isCollapsed)
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Choosing what Vellbar hides"
        alert.informativeText = """
            Vellbar adds two icons: a chevron, and a divider.

            Hold ⌘ and drag the divider along the menu bar. Everything to the \
            left of it is hidden when you collapse; everything to the right \
            always stays on show.

            Click the chevron to collapse or expand. Right-click it for this menu.
            """
        alert.addButton(withTitle: "Got it")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change launch at login"
            alert.informativeText = error.localizedDescription
                + "\n\nMove Vellbar to your Applications folder and try again."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func openDonate() { NSWorkspace.shared.open(Links.donate) }

    @objc func showOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingWindowController { [weak self] in
                self?.onboarding?.close()
                self?.onboarding = nil
            }
        }
        onboarding?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
