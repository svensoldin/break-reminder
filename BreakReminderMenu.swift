import Cocoa

/// Usage: break-reminder-menu [seconds-on-screen] [message]
/// Lives in the menu bar and opens the break-reminder overlay on a user-chosen interval.
private struct OverlaySettings {
    let displayDuration: String
    let message: String
    let executableURL: URL

    static func fromCommandLine(_ arguments: [String]) -> OverlaySettings {
        let options = arguments.dropFirst()
        let siblingDirectory = URL(fileURLWithPath: arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
        return OverlaySettings(
            displayDuration: options.first ?? "30",
            message: options.dropFirst().first ?? "Look away, stretch, breathe.",
            executableURL: siblingDirectory.appendingPathComponent("break-reminder")
        )
    }
}

private enum Preferences {
    static let intervalPresetsInMinutes = [15, 20, 30, 45, 60, 90]
    static let intervalRangeInMinutes = 1...600

    private static let store = UserDefaults(suiteName: "com.breakreminder.menu")!
    private static let isEnabledKey = "isEnabled"
    private static let intervalKey = "intervalMinutes"

    static var isEnabled: Bool {
        get { store.object(forKey: isEnabledKey) as? Bool ?? true }
        set { store.set(newValue, forKey: isEnabledKey) }
    }

    static var intervalInMinutes: Int {
        get { store.object(forKey: intervalKey) as? Int ?? 45 }
        set { store.set(newValue, forKey: intervalKey) }
    }
}

private final class BreakScheduler {
    private(set) var nextBreakDate: Date?
    private(set) var isBreakInProgress = false
    private let overlaySettings: OverlaySettings
    var onChange: () -> Void = {}

    init(overlaySettings: OverlaySettings) {
        self.overlaySettings = overlaySettings
    }

    func restartCountdown() {
        nextBreakDate = Date().addingTimeInterval(TimeInterval(Preferences.intervalInMinutes * 60))
        onChange()
    }

    func stop() {
        nextBreakDate = nil
        onChange()
    }

    func startBreakIfDue() {
        guard let nextBreakDate, Date() >= nextBreakDate, !isBreakInProgress else { return }
        startBreak()
    }

    /// The next countdown starts once the overlay closes, so the break itself isn't counted as work time.
    private func startBreak() {
        let overlay = Process()
        overlay.executableURL = overlaySettings.executableURL
        overlay.arguments = [overlaySettings.displayDuration, overlaySettings.message]
        overlay.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.finishBreak() }
        }
        do {
            try overlay.run()
            isBreakInProgress = true
            onChange()
        } catch {
            restartCountdown()
        }
    }

    private func finishBreak() {
        isBreakInProgress = false
        if Preferences.isEnabled {
            restartCountdown()
        } else {
            stop()
        }
    }
}

private final class BreakReminderMenuApp: NSObject, NSApplicationDelegate {
    private let scheduler: BreakScheduler
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let countdownItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleReminders), keyEquivalent: "")
    private let intervalItem = NSMenuItem(title: "Interval", action: nil, keyEquivalent: "")
    private var clockTimer: Timer?

    init(overlaySettings: OverlaySettings) {
        scheduler = BreakScheduler(overlaySettings: overlaySettings)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        scheduler.onChange = { [weak self] in self?.refresh() }
        if Preferences.isEnabled {
            scheduler.restartCountdown()
        } else {
            scheduler.stop()
        }
        startClock()
        restartCountdownAfterSleep()
    }

    // MARK: - Menu

    private func buildMenu() {
        countdownItem.isEnabled = false
        toggleItem.target = self
        intervalItem.submenu = makeIntervalMenu()

        let menu = NSMenu()
        menu.addItem(countdownItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(intervalItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func makeIntervalMenu() -> NSMenu {
        let menu = NSMenu()
        for minutes in Preferences.intervalPresetsInMinutes {
            let item = NSMenuItem(title: formatInterval(minutes), action: #selector(choosePresetInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let customItem = NSMenuItem(title: "Custom…", action: #selector(chooseCustomInterval), keyEquivalent: "")
        customItem.target = self
        menu.addItem(customItem)
        return menu
    }

    private func refresh() {
        let isEnabled = Preferences.isEnabled
        countdownItem.title = describeCountdown()
        toggleItem.title = isEnabled ? "Turn Off" : "Turn On"
        refreshIntervalCheckmarks()

        let image = NSImage(systemSymbolName: isEnabled ? "eye" : "eye.slash", accessibilityDescription: countdownItem.title)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func refreshIntervalCheckmarks() {
        let interval = Preferences.intervalInMinutes
        let isPreset = Preferences.intervalPresetsInMinutes.contains(interval)
        for item in intervalItem.submenu?.items ?? [] {
            if item.action == #selector(chooseCustomInterval) {
                item.state = isPreset ? .off : .on
                item.title = isPreset ? "Custom…" : "Custom (\(formatInterval(interval)))…"
            } else if !item.isSeparatorItem {
                item.state = item.tag == interval ? .on : .off
            }
        }
    }

    private func describeCountdown() -> String {
        if scheduler.isBreakInProgress { return "Break in progress" }
        guard let nextBreakDate = scheduler.nextBreakDate else { return "Break reminders off" }

        let secondsLeft = max(0, Int(nextBreakDate.timeIntervalSinceNow.rounded(.up)))
        if secondsLeft < 60 { return "Next break in \(secondsLeft)s" }
        return "Next break in \(formatInterval((secondsLeft + 59) / 60))"
    }

    // MARK: - Actions

    @objc private func toggleReminders() {
        Preferences.isEnabled.toggle()
        if Preferences.isEnabled {
            scheduler.restartCountdown()
        } else {
            scheduler.stop()
        }
    }

    @objc private func choosePresetInterval(_ sender: NSMenuItem) {
        applyInterval(sender.tag)
    }

    @objc private func chooseCustomInterval() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = String(Preferences.intervalInMinutes)
        field.placeholderString = "Minutes"

        let alert = NSAlert()
        alert.messageText = "Break interval"
        alert.informativeText = "Minutes between breaks (\(Preferences.intervalRangeInMinutes.lowerBound)–\(Preferences.intervalRangeInMinutes.upperBound))."
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let minutes = Int(field.stringValue.trimmingCharacters(in: .whitespaces)),
              Preferences.intervalRangeInMinutes.contains(minutes) else {
            NSSound.beep()
            return
        }
        applyInterval(minutes)
    }

    private func applyInterval(_ minutes: Int) {
        Preferences.intervalInMinutes = minutes
        if Preferences.isEnabled && !scheduler.isBreakInProgress {
            scheduler.restartCountdown()
        } else {
            refresh()
        }
    }

    // MARK: - Clock

    /// Added in `.common` mode so the countdown keeps ticking while the menu is open.
    private func startClock() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.scheduler.startBreakIfDue()
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    /// Time asleep counts as a break, so waking up starts a fresh countdown.
    private func restartCountdownAfterSleep() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, Preferences.isEnabled, !self.scheduler.isBreakInProgress else { return }
            self.scheduler.restartCountdown()
        }
    }
}

private func formatInterval(_ minutes: Int) -> String {
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    switch (hours, remainingMinutes) {
    case (0, _): return "\(minutes) min"
    case (_, 0): return "\(hours) h"
    default: return "\(hours) h \(remainingMinutes) min"
    }
}

let application = NSApplication.shared
private let delegate = BreakReminderMenuApp(overlaySettings: .fromCommandLine(CommandLine.arguments))
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
