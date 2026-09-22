import Cocoa

/// Usage: break-reminder [seconds-on-screen] [message]
private struct Settings {
    static let title = "Break time"
    static let dismissButtonTitle = "OK"
    static let fadeDuration = 0.35

    let displayDuration: Int
    let message: String

    static func fromCommandLine(_ arguments: [String]) -> Settings {
        let options = arguments.dropFirst()
        return Settings(
            displayDuration: options.first.flatMap(Int.init) ?? 30,
            message: options.dropFirst().first ?? "Look away, stretch, breathe."
        )
    }
}

/// Borderless windows refuse key status by default, which would swallow Return and Escape.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class BreakReminderApp: NSObject, NSApplicationDelegate {
    private var overlayWindows: [OverlayWindow] = []
    private let settings: Settings
    private var remainingSeconds: Int
    private var countdownTimer: Timer?
    private let countdownLabel = makeLabel(text: "", fontSize: 13, color: .secondaryLabelColor)

    init(settings: Settings) {
        self.settings = settings
        self.remainingSeconds = settings.displayDuration
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayWindows = NSScreen.screens.map(makeOverlayWindow(on:))
        addBreakCard(to: overlayWindows.first)
        NSApp.activate(ignoringOtherApps: true)
        fadeIn()
        startCountdown()
    }

    // MARK: - Overlay

    private func makeOverlayWindow(on screen: NSScreen) -> OverlayWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = makeBlurView(frame: NSRect(origin: .zero, size: screen.frame.size))
        window.orderFrontRegardless()
        return window
    }

    private func makeBlurView(frame: NSRect) -> NSVisualEffectView {
        let blurView = NSVisualEffectView(frame: frame)
        blurView.autoresizingMask = [.width, .height]
        blurView.material = .fullScreenUI
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        return blurView
    }

    private func addBreakCard(to window: OverlayWindow?) {
        guard let contentView = window?.contentView else { return }

        let card = NSVisualEffectView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.material = .popover
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 18
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor

        let dismissButton = NSButton(
            title: Settings.dismissButtonTitle,
            target: self,
            action: #selector(dismiss)
        )
        dismissButton.keyEquivalent = "\r"
        dismissButton.bezelStyle = .rounded
        dismissButton.controlSize = .large

        let stack = NSStackView(views: [
            makeLabel(text: Settings.title, fontSize: 28, color: .labelColor),
            makeLabel(text: settings.message, fontSize: 16, color: .labelColor),
            countdownLabel,
            dismissButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(24, after: countdownLabel)

        card.addSubview(stack)
        contentView.addSubview(card)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 380),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 40),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 48),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -48),
        ])

        window?.makeKeyAndOrderFront(nil)
        window?.defaultButtonCell = dismissButton.cell as? NSButtonCell
    }

    private func fadeIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Settings.fadeDuration
            overlayWindows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        refreshCountdownLabel()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        remainingSeconds -= 1
        guard remainingSeconds > 0 else {
            dismiss()
            return
        }
        refreshCountdownLabel()
    }

    private func refreshCountdownLabel() {
        countdownLabel.stringValue = "Closing in \(remainingSeconds)s"
    }

    @objc private func dismiss() {
        countdownTimer?.invalidate()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Settings.fadeDuration
            overlayWindows.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: {
            NSApp.terminate(nil)
        }
    }
}

private func makeLabel(text: String, fontSize: CGFloat, color: NSColor) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: fontSize, weight: fontSize > 20 ? .semibold : .regular)
    label.textColor = color
    label.alignment = .center
    return label
}

let application = NSApplication.shared
private let delegate = BreakReminderApp(settings: .fromCommandLine(CommandLine.arguments))
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
