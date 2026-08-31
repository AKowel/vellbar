import AppKit

/// Vellbar needs two different permissions for two different things, and it is
/// worth being explicit about which buys what — neither is required to hide
/// icons, which is the main job.
@MainActor
final class OnboardingWindowController: NSWindowController {

    private let onDone: () -> Void
    private var recordingRow: PermissionRow!
    private var accessibilityRow: PermissionRow!
    private var pollTask: Task<Void, Never>?

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Vellbar"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func build() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "Two optional permissions")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let intro = NSTextField(wrappingLabelWithString:
            "Hiding menu bar icons works right now, with no permissions at all. "
            + "These two only add to it.")
        intro.font = .systemFont(ofSize: 13)
        intro.textColor = .secondaryLabelColor

        recordingRow = PermissionRow(
            name: "Screen Recording",
            purpose: "To show the actual icons in the list. macOS draws every menu bar "
                   + "item inside one system process and offers no way to read their "
                   + "images, so photographing the menu bar is the only route. Vellbar "
                   + "captures a single strip of the bar, never writes it to disk, and "
                   + "never sends it anywhere.",
            openSettings: { ScreenRecordingPermission.openSystemSettings() },
            request: { ScreenRecordingPermission.request() })

        accessibilityRow = PermissionRow(
            name: "Accessibility",
            purpose: "To open an item for you when you pick it from the list. There is no "
                   + "way to ask another app's icon to activate itself, so Vellbar clicks "
                   + "it where it sits.",
            openSettings: { AccessibilityPermission.openSystemSettings() },
            request: { AccessibilityPermission.promptIfNeeded() })

        let note = NSTextField(wrappingLabelWithString:
            "macOS only applies a new Screen Recording grant after the app restarts.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .tertiaryLabelColor

        let relaunch = NSButton(title: "Relaunch Vellbar", target: self,
                                action: #selector(relaunchApp))
        relaunch.bezelStyle = .rounded

        let done = NSButton(title: "Done", target: self, action: #selector(finish))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"

        let buttons = NSStackView(views: [relaunch, done])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let stack = NSStackView(views: [title, intro, recordingRow, accessibilityRow,
                                        note, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
        ])

        refresh()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refresh()
            }
        }
    }

    private func refresh() {
        recordingRow.setGranted(ScreenRecordingPermission.isGranted)
        accessibilityRow.setGranted(AccessibilityPermission.isTrusted)
    }

    @objc private func relaunchApp() {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    @objc private func finish() { onDone() }

    deinit { pollTask?.cancel() }
}

/// One permission, its reason, and whether it has been granted.
@MainActor
private final class PermissionRow: NSView {

    private let status = NSTextField(labelWithString: "")
    private let button: NSButton
    private let openSettings: () -> Void

    init(name: String, purpose: String,
         openSettings: @escaping () -> Void,
         request: @escaping () -> Bool) {
        self.openSettings = openSettings
        button = NSButton(title: "Allow…", target: nil, action: nil)
        super.init(frame: .zero)

        let heading = NSTextField(labelWithString: name)
        heading.font = .systemFont(ofSize: 13, weight: .semibold)

        let detail = NSTextField(wrappingLabelWithString: purpose)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor

        status.font = .systemFont(ofSize: 11)

        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(tapped)
        self.request = request

        let top = NSStackView(views: [heading, status, NSView(), button])
        top.orientation = .horizontal
        top.spacing = 8

        let stack = NSStackView(views: [top, detail])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private var request: (() -> Bool)?

    @objc private func tapped() {
        // Ask the system first — it shows the prompt the very first time and
        // does nothing afterwards, so also open Settings for the second visit.
        _ = request?()
        openSettings()
    }

    func setGranted(_ granted: Bool) {
        status.stringValue = granted ? "granted" : "not granted"
        status.textColor = granted ? .systemGreen : .tertiaryLabelColor
        button.isHidden = granted
    }
}
