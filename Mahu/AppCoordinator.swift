import Foundation
import OSLog

@MainActor
final class AppCoordinator {
    private static let logger = Logger(subsystem: "Mahu", category: "AppCoordinator")

    private let statusItemController: StatusItemControlling
    private let overlayManager: BreakOverlayManaging
    private let breakCompletionSoundPlayer: BreakCompletionSoundPlaying
    private let makeLaunchAtLoginSettingsStore: @MainActor (AppConfig) -> LaunchAtLoginSettingsStoring
    private let makeLaunchAtLoginController: @MainActor (LaunchAtLoginSettingsStoring) -> LaunchAtLoginSyncing
    private let loadConfig: () -> AppConfig
    private let makeBreakTimer: (AppConfig) -> BreakTimerControlling
    private let scheduleRepeatingTick: RepeatingTickScheduler
    private let currentUptime: CurrentUptimeProvider
    private let currentSleepAwareTime: CurrentSleepAwareTimeProvider
    private let sleepWakeRegistrar: SleepWakeObservationRegistrar

    private var cancelTick: (() -> Void)?
    private var cancelRuntimeSettingsObservation: (() -> Void)?
    private var cancelSleepWakeObservation: SleepWakeObservationCancellation?
    private var breakTimer: BreakTimerControlling?
    private var launchAtLoginSettingsStore: LaunchAtLoginSettingsStoring?
    private var runtimeSettingsStore: RuntimeSettingsStoring?
    private var appliedRuntimeSettings: AppConfig?
    private var runtimeSettingsPolicy = RuntimeSettingsApplicationPolicy()
    private var remindersPaused = false
    private var lastTickUptime: TimeInterval?
    private var lastSleepStartedAt: TimeInterval?
    private var pendingElapsedSeconds: TimeInterval = 0
    private var isStartingBreakPresentation = false

    init(
        statusItemController: StatusItemControlling? = nil,
        overlayManager: BreakOverlayManaging? = nil,
        breakCompletionSoundPlayer: BreakCompletionSoundPlaying? = nil,
        launchAtLoginSettingsStore: LaunchAtLoginSettingsStoring? = nil,
        runtimeSettingsStore: RuntimeSettingsStoring? = nil,
        makeLaunchAtLoginSettingsStore: @escaping @MainActor (AppConfig) -> LaunchAtLoginSettingsStoring = { LaunchAtLoginSettingsStore(initialSettings: $0) },
        makeLaunchAtLoginController: @escaping @MainActor (LaunchAtLoginSettingsStoring) -> LaunchAtLoginSyncing = {
            LaunchAtLoginController(settingsStore: $0, manager: ServiceManagementLaunchAtLoginManager())
        },
        loadConfig: @escaping () -> AppConfig = { ConfigStore().load() },
        makeBreakTimer: @escaping (AppConfig) -> BreakTimerControlling = { BreakTimer(config: $0) },
        scheduleRepeatingTick: @escaping RepeatingTickScheduler = LiveRepeatingScheduler.schedule,
        currentUptime: @escaping CurrentUptimeProvider = { ProcessInfo.processInfo.systemUptime },
        currentSleepAwareTime: @escaping CurrentSleepAwareTimeProvider = LiveSleepAwareTimeSource.now,
        sleepWakeRegistrar: @escaping SleepWakeObservationRegistrar = LiveSleepWakeObservationRegistrar.make
    ) {
        self.statusItemController = statusItemController ?? StatusItemController()
        self.overlayManager = overlayManager ?? BreakOverlayManager()
        self.breakCompletionSoundPlayer = breakCompletionSoundPlayer ?? BreakCompletionSoundPlayer()
        self.launchAtLoginSettingsStore = launchAtLoginSettingsStore
        self.runtimeSettingsStore = runtimeSettingsStore
        self.makeLaunchAtLoginSettingsStore = makeLaunchAtLoginSettingsStore
        self.makeLaunchAtLoginController = makeLaunchAtLoginController
        self.loadConfig = loadConfig
        self.makeBreakTimer = makeBreakTimer
        self.scheduleRepeatingTick = scheduleRepeatingTick
        self.currentUptime = currentUptime
        self.currentSleepAwareTime = currentSleepAwareTime
        self.sleepWakeRegistrar = sleepWakeRegistrar
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
        appliedRuntimeSettings = config
        let launchAtLoginSettingsStore = launchAtLoginSettingsStore ?? makeLaunchAtLoginSettingsStore(config)
        self.launchAtLoginSettingsStore = launchAtLoginSettingsStore
        launchAtLoginSettingsStore.update(config.launchAtLoginEnabled)
        syncLaunchAtLoginDesiredState(using: launchAtLoginSettingsStore, reason: "startup")
        runtimeSettingsPolicy.reset(startupSettings: config)
        let breakTimer = makeBreakTimer(config)
        self.breakTimer = breakTimer
        cancelSleepWakeObservation = sleepWakeRegistrar(
            { [weak self] in
                self?.handleWillSleep()
            },
            { [weak self] in
                self?.handleDidWake()
            }
        )
        remindersPaused = false
        pendingElapsedSeconds = 0
        lastTickUptime = currentUptime()
        statusItemController.setShowsTimerState(config.showStatusItemTimerState)
        handle(state: breakTimer.state)
        cancelTick = scheduleRepeatingTick(1) { [weak self] in
            self?.advanceTimer()
        }
    }

    private func syncLaunchAtLoginDesiredState(
        using settingsStore: LaunchAtLoginSettingsStoring,
        reason: String
    ) {
        let result = makeLaunchAtLoginController(settingsStore).syncDesiredState()

        guard let warning = result.warning else {
            return
        }

        Self.logger.warning(
            "Launch-at-login \(reason, privacy: .public) sync completed with warning \(String(describing: warning), privacy: .public); action=\(String(describing: result.action), privacy: .public), status=\(String(describing: result.status), privacy: .public)."
        )
    }

    private func advanceTimer() {
        guard let breakTimer, let lastTickUptime else {
            return
        }

        let allowBreakCompletionSound = overlayManager.hasActiveBreakSession && overlayManager.hasVisibleOverlayWindows

        if remindersPaused, breakTimer.state.phase == .work {
            self.lastTickUptime = currentUptime()
            return
        }

        let now = currentUptime()
        let elapsedSeconds = max(0, now - lastTickUptime)
        self.lastTickUptime = now

        if breakTimer.state.phase == .rest {
            if overlayManager.hasActiveBreakSession == false {
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
        var overflowElapsedAfterRestCompletion: TimeInterval = 0

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
                overflowElapsedAfterRestCompletion = pendingElapsedSeconds
                break
            }

            if latestState.phase == .rest, overlayManager.hasActiveBreakSession == false {
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

        guard overflowElapsedAfterRestCompletion > 0,
              let currentBreakTimer = self.breakTimer else {
            return
        }

        pendingElapsedSeconds = overflowElapsedAfterRestCompletion
        consumeElapsedTime(using: currentBreakTimer)
    }

    private func handle(state: BreakTimer.State) {
        let state = applyPendingRuntimeSettingsIfNeeded(to: state)
        statusItemController.setStatusDisplayState(.active(phase: state.phase, remainingSeconds: state.remainingSeconds))

        switch state.phase {
        case .work:
            if overlayManager.hasActiveBreakSession {
                overlayManager.hideBreak()
                pendingElapsedSeconds = 0
                lastTickUptime = currentUptime()
            }
        case .rest:
            if overlayManager.hasActiveBreakSession {
                overlayManager.updateRemainingSeconds(state.remainingSeconds)
            } else {
                isStartingBreakPresentation = true
                _ = overlayManager.showBreak(
                    remainingSeconds: state.remainingSeconds,
                    messageText: runtimeSettingsStore?.currentSettings.breakOverlayMessageText ?? AppConfig.defaultBreakOverlayMessageText
                ) { [weak self] in
                    self?.skipBreak()
                }
                isStartingBreakPresentation = false
                if overlayManager.hasActiveBreakSession {
                    pendingElapsedSeconds = 0
                    lastTickUptime = currentUptime()
                }
            }
        }
    }

    private func handleRuntimeSettingsChange(_ newSettings: AppConfig) {
        let previousSettings = appliedRuntimeSettings
        appliedRuntimeSettings = newSettings
        statusItemController.setShowsTimerState(newSettings.showStatusItemTimerState)
        reconcileLaunchAtLoginRuntimeSettingsIfNeeded(newSettings)

        let currentPhase = breakTimer?.state.phase
        let baselineResetAction = timerDisplayBaselineResetAction(
            previousSettings: previousSettings,
            newSettings: newSettings,
            currentPhase: currentPhase,
            remindersPaused: remindersPaused
        )
        let changeDirective = runtimeSettingsPolicy.handleChange(newSettings, currentPhase: currentPhase, remindersPaused: remindersPaused)

        switch baselineResetAction {
        case .none, .clearWhenDeferredSettingsApply:
            break
        case .resetImmediately:
            statusItemController.resetTimerDisplayBaselines()
        case .clearImmediately:
            statusItemController.clearTimerDisplayBaselines()
        }

        guard case .restartActiveWork(let updatedSettings) = changeDirective else {
            return
        }

        pendingElapsedSeconds = 0
        lastTickUptime = currentUptime()
        let newBreakTimer = makeBreakTimer(updatedSettings)
        breakTimer = newBreakTimer
        handle(state: newBreakTimer.state)
    }

    private func reconcileLaunchAtLoginRuntimeSettingsIfNeeded(_ newSettings: AppConfig) {
        guard let launchAtLoginSettingsStore,
              launchAtLoginSettingsStore.launchAtLoginEnabled != newSettings.launchAtLoginEnabled else {
            return
        }

        launchAtLoginSettingsStore.update(newSettings.launchAtLoginEnabled)
        syncLaunchAtLoginDesiredState(using: launchAtLoginSettingsStore, reason: "runtime-settings")
    }

    private func applyPendingRuntimeSettingsIfNeeded(to state: BreakTimer.State) -> BreakTimer.State {
        switch runtimeSettingsPolicy.applyPendingIfNeeded(to: state) {
        case .keep(let currentState):
            return currentState
        case .replaceTimerAndAdvanceToRest(let settings):
            clearTimerDisplayBaselinesIfNeeded(for: settings)
            let newBreakTimer = makeBreakTimer(settings)
            breakTimer = newBreakTimer
            pendingElapsedSeconds = 0
            lastTickUptime = currentUptime()
            return newBreakTimer.advance(by: settings.workDurationSeconds)
        case .replaceTimerAfterRest(let settings):
            clearTimerDisplayBaselinesIfNeeded(for: settings)
            let newBreakTimer = makeBreakTimer(settings)
            breakTimer = newBreakTimer
            pendingElapsedSeconds = 0
            lastTickUptime = currentUptime()
            return newBreakTimer.state
        }
    }

    private func clearTimerDisplayBaselinesIfNeeded(for settings: AppConfig) {
        guard settings.showStatusItemTimerState else {
            return
        }

        statusItemController.clearTimerDisplayBaselines()
    }

    private func handleOverlayVisibilityChange(_ isVisible: Bool) {
        guard overlayManager.hasActiveBreakSession,
              isStartingBreakPresentation == false,
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

    private func handleWillSleep() {
        settleElapsedAwakeTimeBeforeSleep()
        lastSleepStartedAt = currentSleepAwareTime()
    }

    private func handleDidWake() {
        let wokeAt = currentSleepAwareTime()
        let reconciliationAction = wakeReconciliationAction(
            sleepStartedAt: lastSleepStartedAt,
            wokeAt: wokeAt,
            currentState: breakTimer?.state,
            remindersPaused: remindersPaused
        )

        lastSleepStartedAt = nil
        pendingElapsedSeconds = 0
        lastTickUptime = currentUptime()

        guard reconciliationAction != .none else {
            return
        }

        guard let currentSettings = runtimeSettingsStore?.currentSettings else {
            return
        }

        runtimeSettingsPolicy.reset(startupSettings: currentSettings)

        switch reconciliationAction {
        case .none, .preservePausedWork:
            return
        case .resetActiveWork, .resetAfterActiveRest:
            let newBreakTimer = makeBreakTimer(currentSettings)
            breakTimer = newBreakTimer
            handle(state: newBreakTimer.state)
        }
    }

    private func settleElapsedAwakeTimeBeforeSleep() {
        guard let breakTimer, let lastTickUptime else {
            return
        }

        let now = currentUptime()
        self.lastTickUptime = now

        if remindersPaused, breakTimer.state.phase == .work {
            return
        }

        if breakTimer.state.phase == .rest,
           (overlayManager.hasActiveBreakSession == false || overlayManager.hasVisibleOverlayWindows == false) {
            return
        }

        let elapsedSeconds = max(0, now - lastTickUptime)
        guard elapsedSeconds > 0 else {
            return
        }

        pendingElapsedSeconds += elapsedSeconds
        // Sleep-entry settlement must not treat an interrupted break as a natural audible completion.
        consumeElapsedTime(using: breakTimer, allowBreakCompletionSound: false)
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
        cancelSleepWakeObservation?()
        cancelRuntimeSettingsObservation?()
        cancelTick?()
    }
}
