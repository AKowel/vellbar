import AppKit

/// The permission grant is where an app like this loses people, so it gets an
/// explanation rather than a bare system dialog.
@MainActor
final class OnboardingWindowController: NSWindowController {

    private let onGranted: () -> Void
    private var statusLabel: NSTextField!
    private var pollTask: Task<Void, Never>?

    init(onGranted: @escaping () -> Void) {
        self.onGranted = onGranted
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 270),
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

        let title = NSTextField(labelWithString: "Vellbar needs Accessibility access")
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: """
            Vellbar can hide menu bar icons without any permission at all. Accessibility is \
            only needed to *name* the items in its list — without it you still get a \
            count, just not the names.

            It reads no keystrokes, sends nothing anywhere, and has no account.

            Open System Settings, find Vellbar in the list, and switch it on. \
            This window closes itself once it's done.
            """)
        body.font = .systemFont(ofSize: 13)
        body.textColor = .secondaryLabelColor

        let button = NSButton(title: "Open System Settings",
                              target: self, action: #selector(openSettings))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"

        statusLabel = NSTextField(labelWithString: "Waiting for access…")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [title, body, button, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
        ])

        AccessibilityPermission.promptIfNeeded()
        pollTask = AccessibilityPermission.waitForGrant { [weak self] in
            self?.statusLabel.stringValue = "Access granted."
            self?.onGranted()
        }
    }

    @objc private func openSettings() {
        AccessibilityPermission.openSystemSettings()
    }

    deinit { pollTask?.cancel() }
}
