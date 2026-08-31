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

        // Explain the drag once. Without it the app looks broken on first run:
        // it adds two icons and appears to do nothing, because macOS put the
        // divider where it hides nothing.
        if !UserDefaults.standard.bool(forKey: "vellbar.sawSetup") {
            UserDefaults.standard.set(true, forKey: "vellbar.sawSetup")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                self.showHelp()
            }
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

        if !AccessibilityPermission.isTrusted {
            // Not optional: the window list does not expose third-party status
            // items at all, so Accessibility is the only way to find them.
            addReadout(menu, "Accessibility access required")
            addReadout(menu, "macOS won't list menu bar items without it")
            let grant = NSMenuItem(title: "Set up…",
                                   action: #selector(showOnboarding), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        } else if items.isEmpty {
            addReadout(menu, "Couldn't read the menu bar on this macOS")
            let grant = NSMenuItem(title: "Set up…",
                                   action: #selector(showOnboarding), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        } else if !ScreenRecordingPermission.isGranted {
            addReadout(menu, "\(items.count) menu bar item\(items.count == 1 ? "" : "s")")
            addReadout(menu, "Allow Screen Recording to see their icons")
            let grant = NSMenuItem(title: "Set up icons…",
                                   action: #selector(showOnboarding), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
            menu.addItem(.separator())
            for (index, item) in items.enumerated() {
                let row = NSMenuItem(title: title(for: item, index: index),
                                     action: #selector(activate(_:)), keyEquivalent: "")
                row.target = self
                row.representedObject = NSValue(point: item.clickPoint)
                menu.addItem(row)
            }
        } else if false {
            addReadout(menu, "No menu bar items found")
        } else if separator?.wouldHideNothing == true {
            // The single most common state on first launch, and previously the
            // app just sat there looking broken.
            addReadout(menu, "Nothing is set to hide yet")
            let setup = NSMenuItem(title: "Set up hiding…",
                                   action: #selector(showHelp), keyEquivalent: "")
            setup.target = self
            menu.addItem(setup)
            menu.addItem(.separator())
            addReadout(menu, "\(items.count) menu bar items")
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
        alert.messageText = "One drag, and you're set up"
        alert.informativeText = """
            macOS drops new menu bar icons at the far left and gives apps no way \
            to move themselves — so Vellbar needs one drag from you. Every app \
            that does this works the same way.

            1.  Find Vellbar's divider (the small ☰ icon).
            2.  Hold ⌘ and drag it to the RIGHT, past every icon you want hidden.
            3.  Click the chevron to collapse.

            Everything to the left of the divider hides. Everything to the right \
            stays on show. Right-click the chevron any time for the full list — \
            you can open any item from there, even while it's hidden.
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
