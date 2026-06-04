import AppKit

final class StatusItemController: NSObject {
    private static let menuBarIconSize = NSSize(width: 18, height: 18)
    private static let pauseRemindersTitle = "Pause Reminders"
    private static let resumeRemindersTitle = "Resume Reminders"
    private static let normalStatusItemAlpha: CGFloat = 1.0
    private static let pausedStatusItemAlpha: CGFloat = 0.5

    private let statusItem: NSStatusItem
    private var pauseRemindersHandler: (() -> Void)?
    private var resumeRemindersHandler: (() -> Void)?
    private let applicationTerminator: () -> Void
    private let statusIconProvider: () -> NSImage?

    private var remindersPaused = false

    init(
        statusItem: NSStatusItem? = nil,
        statusBar: NSStatusBar = .system,
        applicationTerminator: @escaping () -> Void = { NSApp.terminate(nil) },
        statusIconProvider: @escaping () -> NSImage? = { StatusItemController.makeDefaultStatusIcon() }
    ) {
        self.statusItem = statusItem ?? statusBar.statusItem(withLength: NSStatusItem.squareLength)
        self.applicationTerminator = applicationTerminator
        self.statusIconProvider = statusIconProvider
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.title = ""
            button.image = statusIconProvider()
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
        }

        applyReminderVisualState()

        statusItem.menu = makeMenu()
    }

    func configureReminderActions(onPause: @escaping () -> Void, onResume: @escaping () -> Void) {
        pauseRemindersHandler = onPause
        resumeRemindersHandler = onResume
    }

    func setRemindersPaused(_ paused: Bool) {
        guard remindersPaused != paused || statusItem.menu == nil else {
            return
        }

        remindersPaused = paused
        applyReminderVisualState()
        statusItem.menu = makeMenu()
    }

    @objc private func quit() {
        applicationTerminator()
    }

    @objc private func toggleRemindersPauseState() {
        guard let pauseRemindersHandler, let resumeRemindersHandler else {
            preconditionFailure("StatusItemController reminder actions must be configured before use")
        }

        if remindersPaused {
            resumeRemindersHandler()
        } else {
            pauseRemindersHandler()
        }
    }

    static func makeTrayTemplateStatusIcon(bundle: Bundle = .main) -> NSImage? {
        guard let image = bundle.image(forResource: NSImage.Name("TrayIconTemplate")) else {
            return nil
        }

        return makeMenuBarStatusIconCopy(from: image)
    }

    static func makeDefaultStatusIcon(
        trayIconProvider: () -> NSImage? = { makeTrayTemplateStatusIcon(bundle: .main) },
        appIconProvider: () -> NSImage? = {
            let namedAppIcon = NSImage(named: NSImage.applicationIconName)
            return namedAppIcon ?? NSApp.applicationIconImage
        }
    ) -> NSImage? {
        if let trayIcon = trayIconProvider() {
            return makeMenuBarStatusIconCopy(from: trayIcon)
        }

        guard let appIcon = appIconProvider() else {
            return nil
        }

        return makeMenuBarStatusIconCopy(from: appIcon)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let pauseResumeItem = NSMenuItem(
            title: remindersPaused ? Self.resumeRemindersTitle : Self.pauseRemindersTitle,
            action: #selector(toggleRemindersPauseState),
            keyEquivalent: ""
        )
        pauseResumeItem.target = self
        menu.addItem(pauseResumeItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func applyReminderVisualState() {
        guard let button = statusItem.button else {
            return
        }

        button.alphaValue = remindersPaused ? Self.pausedStatusItemAlpha : Self.normalStatusItemAlpha
        button.isEnabled = true
    }

    private static func makeMenuBarStatusIconCopy(from image: NSImage) -> NSImage? {
        guard let copiedImage = image.copy() as? NSImage else {
            return nil
        }

        copiedImage.size = menuBarIconSize
        copiedImage.isTemplate = true
        return copiedImage
    }
}
