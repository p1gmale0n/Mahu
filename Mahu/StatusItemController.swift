import AppKit

final class StatusItemController: NSObject {
    private static let menuBarIconSize = NSSize(width: 18, height: 18)
    private static let timerStateTitlePrefix = "  "
    private static let pauseRemindersTitle = "Pause Reminders"
    private static let resumeRemindersTitle = "Resume Reminders"
    private static let normalStatusItemAlpha: CGFloat = 1.0
    private static let pausedStatusItemAlpha: CGFloat = 0.5
    private static let minimumTimerStatusItemLength = NSStatusItem.squareLength

    private let statusItem: NSStatusItem
    private var pauseRemindersHandler: (() -> Void)?
    private var resumeRemindersHandler: (() -> Void)?
    private let applicationTerminator: () -> Void
    private let statusIconProvider: () -> NSImage?
    private let statusDisplayFormatter = StatusDisplayFormatter()

    private var remindersPaused = false
    private var showsTimerState = false
    private var statusDisplayState: StatusDisplayState?
    private var installedStatusIcon: NSImage?
    private var maximumTimerStatusItemLength: CGFloat = 0

    private var reminderActionsAreConfigured: Bool {
        pauseRemindersHandler != nil && resumeRemindersHandler != nil
    }

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
        if installedStatusIcon == nil {
            installedStatusIcon = statusIconProvider()
            installedStatusIcon?.isTemplate = true
        }

        applyStatusItemDisplay()
        applyReminderVisualState()

        statusItem.menu = makeMenu()
    }

    func configureReminderActions(onPause: @escaping () -> Void, onResume: @escaping () -> Void) {
        pauseRemindersHandler = onPause
        resumeRemindersHandler = onResume

        if statusItem.menu != nil {
            statusItem.menu = makeMenu()
        }
    }

    func setRemindersPaused(_ paused: Bool) {
        guard remindersPaused != paused || statusItem.menu == nil else {
            return
        }

        remindersPaused = paused
        applyStatusItemDisplay()
        applyReminderVisualState()
        statusItem.menu = makeMenu()
    }

    func setShowsTimerState(_ showsTimerState: Bool) {
        guard self.showsTimerState != showsTimerState else {
            return
        }

        self.showsTimerState = showsTimerState

        if showsTimerState == false {
            maximumTimerStatusItemLength = 0
        }

        applyStatusItemDisplay()
    }

    func setStatusDisplayState(_ statusDisplayState: StatusDisplayState) {
        self.statusDisplayState = statusDisplayState

        guard showsTimerState else {
            return
        }

        applyStatusItemDisplay()
    }

    @objc private func quit() {
        applicationTerminator()
    }

    @objc private func toggleRemindersPauseState() {
        guard let pauseRemindersHandler, let resumeRemindersHandler else {
            return
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
        pauseResumeItem.isEnabled = reminderActionsAreConfigured
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

    private func applyStatusItemDisplay() {
        guard let button = statusItem.button else {
            return
        }

        button.image = installedStatusIcon

        if showsTimerState {
            button.attributedTitle = makeTimerStateTitle(currentTimerStateText())
            button.imagePosition = .imageLeading
            let measuredLength = measuredTimerStatusItemLength(for: button)
            maximumTimerStatusItemLength = max(maximumTimerStatusItemLength, measuredLength)
            statusItem.length = maximumTimerStatusItemLength
            return
        }

        maximumTimerStatusItemLength = 0
        statusItem.length = NSStatusItem.squareLength
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.imagePosition = .imageOnly
    }

    private func makeTimerStateTitle(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: Self.timerStateTitlePrefix + text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: NSFont.systemFontSize,
                    weight: .regular
                )
            ]
        )
    }

    private func currentTimerStateText() -> String {
        guard let statusDisplayState else {
            return remindersPaused ? statusDisplayFormatter.string(for: .paused) : ""
        }

        switch statusDisplayState {
        case let .active(phase, remainingSeconds):
            if remindersPaused, phase == .work {
                return statusDisplayFormatter.string(for: .paused)
            }

            return statusDisplayFormatter.string(
                for: .active(phase: phase, remainingSeconds: remainingSeconds)
            )
        case .paused:
            return statusDisplayFormatter.string(for: .paused)
        }
    }

    private func measuredTimerStatusItemLength(for button: NSStatusBarButton) -> CGFloat {
        max(Self.minimumTimerStatusItemLength, ceil(button.fittingSize.width))
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
