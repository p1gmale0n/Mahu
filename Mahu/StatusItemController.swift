import AppKit

@MainActor
final class StatusItemController: NSObject {
    private static let menuBarIconSize = NSSize(width: 18, height: 18)
    private static let timerStateTitlePrefix = "  "
    private static let pauseRemindersTitle = "Pause Reminders"
    private static let resumeRemindersTitle = "Resume Reminders"
    private static let normalStatusItemAlpha: CGFloat = 1.0
    private static let pausedStatusItemAlpha: CGFloat = 0.5
    private static let minimumTimerStatusItemLength = NSStatusItem.squareLength
    private static let timerTitleSlotTerminator = "\t"

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
    private var pausedStatusIcon: NSImage?
    private var maximumTimerStatusItemLength: CGFloat = 0
    private var maximumTimerTitleSlotWidth: CGFloat = 0

    var timerDisplayBaselines: (itemLength: CGFloat, titleSlotWidth: CGFloat) {
        (maximumTimerStatusItemLength, maximumTimerTitleSlotWidth)
    }

    private var reminderActionsAreConfigured: Bool {
        pauseRemindersHandler != nil && resumeRemindersHandler != nil
    }

    init(
        statusItem: NSStatusItem? = nil,
        statusBar: NSStatusBar = .system,
        applicationTerminator: (() -> Void)? = nil,
        statusIconProvider: (() -> NSImage?)? = nil
    ) {
        self.statusItem = statusItem ?? statusBar.statusItem(withLength: NSStatusItem.squareLength)
        self.applicationTerminator = applicationTerminator ?? { NSApp.terminate(nil) }
        self.statusIconProvider = statusIconProvider ?? { StatusItemController.makeDefaultStatusIcon() }
        super.init()
    }

    func install() {
        if installedStatusIcon == nil {
            installedStatusIcon = statusIconProvider()
            installedStatusIcon?.isTemplate = true
            pausedStatusIcon = installedStatusIcon.flatMap {
                Self.makeMenuBarStatusIconCopy(from: $0, alpha: Self.pausedStatusItemAlpha)
            }
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
            resetTimerDisplayBaselines()
            return
        }

        applyStatusItemDisplay()
    }

    func resetTimerDisplayBaselines() {
        maximumTimerStatusItemLength = 0
        maximumTimerTitleSlotWidth = 0
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
        trayIconProvider: (() -> NSImage?)? = nil,
        appIconProvider: (() -> NSImage?)? = nil
    ) -> NSImage? {
        let resolvedTrayIconProvider = trayIconProvider ?? { makeTrayTemplateStatusIcon(bundle: .main) }
        let resolvedAppIconProvider = appIconProvider ?? {
            let namedAppIcon = NSImage(named: NSImage.applicationIconName)
            return namedAppIcon ?? NSApp.applicationIconImage
        }

        if let trayIcon = resolvedTrayIconProvider() {
            return makeMenuBarStatusIconCopy(from: trayIcon)
        }

        guard let appIcon = resolvedAppIconProvider() else {
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

        button.image = currentStatusIcon()
        button.alphaValue = Self.normalStatusItemAlpha
        button.isEnabled = true
    }

    private func applyStatusItemDisplay() {
        guard let button = statusItem.button else {
            return
        }

        button.image = currentStatusIcon()

        if showsTimerState {
            let timerStateText = currentTimerStateText()
            maximumTimerTitleSlotWidth = max(
                maximumTimerTitleSlotWidth,
                requiredTimerTitleSlotWidth(for: timerStateText)
            )
            button.attributedTitle = makeTimerStateTitle(
                timerStateText,
                slotWidth: maximumTimerTitleSlotWidth
            )
            button.imagePosition = .imageLeading
            let measuredLength = measuredTimerStatusItemLength(for: button)
            maximumTimerStatusItemLength = max(maximumTimerStatusItemLength, measuredLength)
            statusItem.length = maximumTimerStatusItemLength
            return
        }

        maximumTimerStatusItemLength = 0
        maximumTimerTitleSlotWidth = 0
        statusItem.length = NSStatusItem.squareLength
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.imagePosition = .imageOnly
    }

    private func makeTimerStateTitle(_ text: String, slotWidth: CGFloat) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [
            NSTextTab(textAlignment: .left, location: ceil(slotWidth), options: [:])
        ]

        return NSAttributedString(
            string: Self.timerStateTitlePrefix + text + Self.timerTitleSlotTerminator,
            attributes: [
                .font: Self.timerDisplayFont,
                .paragraphStyle: paragraphStyle
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
        let fittingWidth = ceil(button.fittingSize.width)
        let intrinsicWidth = button.intrinsicContentSize.width
        let naturalWidth = intrinsicWidth == NSView.noIntrinsicMetric ? 0 : ceil(intrinsicWidth)

        return max(Self.minimumTimerStatusItemLength, max(fittingWidth, naturalWidth))
    }

    private func measuredTimerTitleSlotWidth(for text: String) -> CGFloat {
        ceil(
            NSAttributedString(
                string: Self.timerStateTitlePrefix + text,
                attributes: [.font: Self.timerDisplayFont]
            ).size().width
        )
    }

    private func requiredTimerTitleSlotWidth(for text: String) -> CGFloat {
        max(
            measuredTimerTitleSlotWidth(for: text),
            measuredTimerTitleSlotWidth(for: statusDisplayFormatter.string(for: .paused))
        )
    }

    private func currentStatusIcon() -> NSImage? {
        if remindersPaused, let pausedStatusIcon {
            return pausedStatusIcon
        }

        return installedStatusIcon
    }

    private static var timerDisplayFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    private static func makeMenuBarStatusIconCopy(from image: NSImage, alpha: CGFloat = 1.0) -> NSImage? {
        let copiedImage = NSImage(size: menuBarIconSize)
        copiedImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: menuBarIconSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: alpha
        )
        copiedImage.unlockFocus()
        copiedImage.isTemplate = true
        return copiedImage
    }
}
