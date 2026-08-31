import AppKit
import ServiceManagement
import VellbarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var separator: SeparatorController?
    private var onboarding: OnboardingWindowController?
    private let icons = IconCapture()
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = SeparatorController()
        controller.buildMenu = { [weak self] in self?.menu() ?? NSMenu() }
        separator = controller

        startCapturing()

        if !ScreenRecordingPermission.isGranted {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTask?.cancel()
    }

    /// Photograph the bar while it is expanded, so hidden items still have an
    /// icon to show. An item that has been pushed off-screen cannot be
    /// captured, so the cache is the only way its icon survives collapsing.
    private func startCapturing() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.separator?.isCollapsed == false {
                    await self.icons.refresh(items: MenuBarScanner.scan())
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: Menu

    private func menu() -> NSMenu {
        let menu = NSMenu()
        let items = MenuBarScanner.scan()

        if !ScreenRecordingPermission.isGranted {
            addReadout(menu, "\(items.count) menu bar item\(items.count == 1 ? "" : "s")")
            addReadout(menu, "Allow Screen Recording to see their icons")
            let grant = NSMenuItem(title: "Set up icons…",
                                   action: #selector(showOnboarding), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        } else if items.isEmpty {
            addReadout(menu, "No menu bar items found")
        } else {
            addReadout(menu, "Menu bar items")
            for (index, item) in items.enumerated() {
                let row = NSMenuItem(title: title(for: item, index: index),
                                     action: #selector(activate(_:)), keyEquivalent: "")
                row.target = self
                row.representedObject = NSValue(point: item.clickPoint)
                if let icon = icons.image(for: item.windowID) {
                    icon.size = NSSize(width: 18, height: 18)
                    row.image = icon
                }
                menu.addItem(row)
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

    /// The icon carries the identity, so the label only has to disambiguate.
    /// A captured picture of a status item tells you what it is far better than
    /// any name macOS is willing to give us.
    private func title(for item: MenuBarItem, index: Int) -> String {
        if let name = item.name, !name.isEmpty { return name }
        return item.looksLikeText ? "Text item \(index + 1)" : "Item \(index + 1)"
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
        // The item may be pushed off-screen right now, so reveal, click, restore.
        separator?.revealing {
            ItemActivator.click(at: CGPoint(x: point.x, y: point.y))
        }
    }

    @objc private func toggleCollapse() {
        guard let separator else { return }
        separator.setCollapsed(!separator.isCollapsed)
        if !separator.isCollapsed {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                await icons.refresh(items: MenuBarScanner.scan(), force: true)
            }
        }
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Choosing what Vellbar hides"
        alert.informativeText = """
            Vellbar adds two icons: a chevron, and a divider.

            Hold ⌘ and drag the divider along the menu bar. Everything to the \
            left of it is hidden when you collapse; everything to the right \
            always stays on show.

            Click the chevron to collapse or expand. Right-click it for the list \
            of items, and click any of them to open it — even while it's hidden.
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
                self?.startCapturing()
            }
        }
        onboarding?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
