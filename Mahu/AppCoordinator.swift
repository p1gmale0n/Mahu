import Foundation

@MainActor
final class AppCoordinator {
    private let statusItemController: StatusItemControlling
    private let overlayManager: BreakOverlayManaging
    private let breakCompletionSoundPlayer: BreakCompletionSoundPlaying
    private let loadConfig: () -> AppConfig
    private let makeBreakTimer: (AppConfig) -> BreakTimerControlling
    private let scheduleRepeatingTick: RepeatingTickScheduler
    private let currentUptime: CurrentUptimeProvider

    private var cancelTick: (() -> Void)?
    private var cancelRuntimeSettingsObservation: (() -> Void)?
    private var breakTimer: BreakTimerControlling?
    private var runtimeSettingsStore: RuntimeSettingsStoring?
    private var runtimeSettingsPolicy = RuntimeSettingsApplicationPolicy()
    private var isShowingBreak = false
    private var remindersPaused = false
    private var lastTickUptime: TimeInterval?
    private var pendingElapsedSeconds: TimeInterval = 0

    init(
        statusItemController: StatusItemControlling? = nil,
        overlayManager: BreakOverlayManaging? = nil,
        breakCompletionSoundPlayer: BreakCompletionSoundPlaying? = nil,
        runtimeSettingsStore: RuntimeSettingsStoring? = nil,
        loadConfig: @escaping () -> AppConfig = { ConfigStore().load() },
        makeBreakTimer: @escaping (AppConfig) -> BreakTimerControlling = { BreakTimer(config: $0) },
        scheduleRepeatingTick: @escaping RepeatingTickScheduler = LiveRepeatingScheduler.schedule,
        currentUptime: @escaping CurrentUptimeProvider = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.statusItemController = statusItemController ?? StatusItemController()
        self.overlayManager = overlayManager ?? BreakOverlayManager()
        self.breakCompletionSoundPlayer = breakCompletionSoundPlayer ?? BreakCompletionSoundPlayer()
        self.runtimeSettingsStore = runtimeSettingsStore
        self.loadConfig = loadConfig
        self.makeBreakTimer = makeBreakTimer
        self.scheduleRepeatingTick = scheduleRepeatingTick
        self.currentUptime = currentUptime
        self.overlayManager.onVisibleOverlayWindowsChange = { [weak self] isVisible in
            self?.handleOverlayVisibilityChange(isVisible)
        }
    }

    func start() {
        guard cancelTick == nil else {
            return
        }

        statusItemController.configureReminderActions(
            onPause: { [weak self] in
                self?.pauseReminders()
            },
            onResume: { [weak self] in
                self?.resumeReminders()
            }
        )
        statusItemController.install()

        let runtimeSettingsStore = runtimeSettingsStore ?? RuntimeSettingsStore(initialSettings: loadConfig())
        self.runtimeSettingsStore = runtimeSettingsStore
        cancelRuntimeSettingsObservation = runtimeSettingsStore.addObserver { [weak self] newSettings in
            self?.handleRuntimeSettingsChange(newSettings)
        }
        let config = runtimeSettingsStore.currentSettings
        runtimeSettingsPolicy.reset(startupSettings: config)
        let breakTimer = makeBreakTimer(config)
        self.breakTimer = breakTimer
        remindersPaused = false
        pendingElapsedSeconds = 0
        lastTickUptime = currentUptime()
        statusItemController.setShowsTimerState(config.showStatusItemTimerState)
        handle(state: breakTimer.state)
        cancelTick = scheduleRepeatingTick(1) { [weak self] in
            self?.advanceTimer()
        }
    }

    private func advanceTimer() {
        guard let breakTimer, let lastTickUptime else {
            return
        }

        let allowBreakCompletionSound = isShowingBreak && overlayManager.hasVisibleOverlayWindows

        if remindersPaused, breakTimer.state.phase == .work {
            self.lastTickUptime = currentUptime()
            return
        }

        let now = currentUptime()
        let elapsedSeconds = max(0, now - lastTickUptime)
        self.lastTickUptime = now

        if breakTimer.state.phase == .rest {
            if isShowingBreak == false {
                handle(state: breakTimer.state)
                return
            }

            if overlayManager.hasVisibleOverlayWindows == false {
                return
            }
        }

        guard elapsedSeconds > 0 else {
            return
        }

        pendingElapsedSeconds += elapsedSeconds
        consumeElapsedTime(
            using: breakTimer,
            allowBreakCompletionSound: allowBreakCompletionSound
        )
    }

    private func consumeElapsedTime(
        using breakTimer: BreakTimerControlling,
        allowBreakCompletionSound: Bool = false
    ) {
        var latestState = breakTimer.state
        var didAdvance = false
        var shouldPlayBreakCompletionSound = false

        while true {
            let elapsedToConsume = elapsedTimeToConsume(
                pendingElapsedSeconds: pendingElapsedSeconds,
                for: latestState
            )
            guard elapsedToConsume > 0 else {
                break
            }

            let previousPhase = latestState.phase
            pendingElapsedSeconds = max(0, pendingElapsedSeconds - elapsedToConsume)
            latestState = breakTimer.advance(by: elapsedToConsume)
            didAdvance = true

            if previousPhase == .rest, latestState.phase == .work {
                shouldPlayBreakCompletionSound = allowBreakCompletionSound
                break
            }

            if latestState.phase == .rest, isShowingBreak == false {
                break
            }
        }

        guard didAdvance else {
            return
        }

        handle(state: latestState)

        if shouldPlayBreakCompletionSound {
            breakCompletionSoundPlayer.playBreakCompletionSound()
        }
    }

    private func handle(state: BreakTimer.State) {
        let state = applyPendingRuntimeSettingsIfNeeded(to: state)
        statusItemController.setStatusDisplayState(.active(phase: state.phase, remainingSeconds: state.remainingSeconds))

        switch state.phase {
        case .work:
            if isShowingBreak {
                overlayManager.hideBreak()
                isShowingBreak = false
                pendingElapsedSeconds = 0
                lastTickUptime = currentUptime()
            }
        case .rest:
            if isShowingBreak {
                overlayManager.updateRemainingSeconds(state.remainingSeconds)
            } else {
                isShowingBreak = overlayManager.showBreak(
                    remainingSeconds: state.remainingSeconds,
                    messageText: runtimeSettingsStore?.currentSettings.breakOverlayMessageText ?? AppConfig.defaultBreakOverlayMessageText
                ) { [weak self] in
                    self?.skipBreak()
                }
                if isShowingBreak {
                    pendingElapsedSeconds = 0
                    lastTickUptime = currentUptime()
                }
            }
        }
    }

    private func handleRuntimeSettingsChange(_ newSettings: AppConfig) {
        statusItemController.setShowsTimerState(newSettings.showStatusItemTimerState)

        let currentPhase = breakTimer?.state.phase
        let changeDirective = runtimeSettingsPolicy.handleChange(newSettings, currentPhase: currentPhase, remindersPaused: remindersPaused)

        guard case .restartActiveWork(let updatedSettings) = changeDirective else {
            return
        }

        pendingElapsedSeconds = 0
        lastTickUptime = currentUptime()
        let newBreakTimer = makeBreakTimer(updatedSettings)
        breakTimer = newBreakTimer
        handle(state: newBreakTimer.state)
    }

    private func applyPendingRuntimeSettingsIfNeeded(to state: BreakTimer.State) -> BreakTimer.State {
        switch runtimeSettingsPolicy.applyPendingIfNeeded(to: state) {
        case .keep(let currentState):
            return currentState
        case .replaceTimerAndAdvanceToRest(let settings):
            let newBreakTimer = makeBreakTimer(settings)
            breakTimer = newBreakTimer
            pendingElapsedSeconds = 0
            lastTickUptime = currentUptime()
            return newBreakTimer.advance(by: settings.workDurationSeconds)
        case .replaceTimerAfterRest(let settings):
            let newBreakTimer = makeBreakTimer(settings)
            breakTimer = newBreakTimer
            pendingElapsedSeconds = 0
            lastTickUptime = currentUptime()
            return newBreakTimer.state
        }
    }

    private func handleOverlayVisibilityChange(_ isVisible: Bool) {
        guard isShowingBreak,
              let breakTimer,
              breakTimer.state.phase == .rest,
              let lastTickUptime else {
            return
        }

        let now = currentUptime()
        let elapsedSeconds = max(0, now - lastTickUptime)
        self.lastTickUptime = now

        guard isVisible == false, elapsedSeconds > 0 else {
            return
        }

        pendingElapsedSeconds += elapsedSeconds
        consumeElapsedTime(using: breakTimer, allowBreakCompletionSound: true)
    }

    private func skipBreak() {
        guard let breakTimer else {
            return
        }

        let state = breakTimer.skipBreak()
        handle(state: state)
    }

    private func pauseReminders() {
        guard remindersPaused == false else {
            if breakTimer?.state.phase == .work {
                pendingElapsedSeconds = 0
                lastTickUptime = currentUptime()
            }
            return
        }

        remindersPaused = true
        pendingElapsedSeconds = 0
        statusItemController.setRemindersPaused(true)
    }

    private func resumeReminders() {
        guard remindersPaused else {
            return
        }

        remindersPaused = false
        if breakTimer?.state.phase == .work {
            pendingElapsedSeconds = 0
            lastTickUptime = currentUptime()

            if let currentSettings = runtimeSettingsStore?.currentSettings {
                runtimeSettingsPolicy.reset(startupSettings: currentSettings)
                breakTimer = makeBreakTimer(currentSettings)
            }
        }

        if let breakTimer {
            handle(state: breakTimer.state)
        }

        statusItemController.setRemindersPaused(false)
    }

    isolated deinit {
        cancelRuntimeSettingsObservation?()
        cancelTick?()
    }
}
