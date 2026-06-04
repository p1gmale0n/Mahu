import Foundation

protocol BreakTimerControlling: AnyObject {
    var state: BreakTimer.State { get }

    @discardableResult
    func advance(by elapsedSeconds: TimeInterval) -> BreakTimer.State

    @discardableResult
    func skipBreak() -> BreakTimer.State
}

protocol StatusItemControlling: AnyObject {
    func install()
    func configureReminderActions(onPause: @escaping () -> Void, onResume: @escaping () -> Void)
    func setRemindersPaused(_ paused: Bool)
}

typealias RepeatingTickScheduler = (TimeInterval, @escaping () -> Void) -> () -> Void
typealias CurrentUptimeProvider = () -> TimeInterval
typealias OverlayVisibilityChangeHandler = (Bool) -> Void

@MainActor
protocol BreakOverlayManaging: AnyObject {
    var hasVisibleOverlayWindows: Bool { get }
    var onVisibleOverlayWindowsChange: OverlayVisibilityChangeHandler? { get set }
    @discardableResult
    func showBreak(remainingSeconds: TimeInterval, onSkip: @escaping () -> Void) -> Bool
    func updateRemainingSeconds(_ remainingSeconds: TimeInterval)
    func hideBreak()
}

enum LiveRepeatingScheduler {
    static func schedule(interval: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            action()
        }

        RunLoop.main.add(timer, forMode: .common)

        return {
            timer.invalidate()
        }
    }
}

@MainActor
final class AppCoordinator {
    private let statusItemController: StatusItemControlling
    private let overlayManager: BreakOverlayManaging
    private let loadConfig: () -> AppConfig
    private let makeBreakTimer: (AppConfig) -> BreakTimerControlling
    private let scheduleRepeatingTick: RepeatingTickScheduler
    private let currentUptime: CurrentUptimeProvider

    private var cancelTick: (() -> Void)?
    private var breakTimer: BreakTimerControlling?
    private var isShowingBreak = false
    private var remindersPaused = false
    private var lastTickUptime: TimeInterval?
    private var pendingElapsedSeconds: TimeInterval = 0
    private var activeConfig: AppConfig?

    init(
        statusItemController: StatusItemControlling? = nil,
        overlayManager: BreakOverlayManaging? = nil,
        loadConfig: @escaping () -> AppConfig = { ConfigStore().load() },
        makeBreakTimer: @escaping (AppConfig) -> BreakTimerControlling = { BreakTimer(config: $0) },
        scheduleRepeatingTick: @escaping RepeatingTickScheduler = LiveRepeatingScheduler.schedule,
        currentUptime: @escaping CurrentUptimeProvider = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.statusItemController = statusItemController ?? StatusItemController()
        self.overlayManager = overlayManager ?? BreakOverlayManager()
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

        let config = loadConfig()
        activeConfig = config
        let breakTimer = makeBreakTimer(config)
        self.breakTimer = breakTimer
        remindersPaused = false
        pendingElapsedSeconds = 0
        lastTickUptime = currentUptime()
        handle(state: breakTimer.state)
        cancelTick = scheduleRepeatingTick(1) { [weak self] in
            self?.advanceTimer()
        }
    }

    private func advanceTimer() {
        guard let breakTimer, let lastTickUptime else {
            return
        }

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
        consumeElapsedTime(using: breakTimer)
    }

    private func consumeElapsedTime(using breakTimer: BreakTimerControlling) {
        var latestState = breakTimer.state
        var didAdvance = false

        while true {
            let elapsedToConsume = elapsedToConsume(for: latestState)
            guard elapsedToConsume > 0 else {
                break
            }

            let previousPhase = latestState.phase
            pendingElapsedSeconds = max(0, pendingElapsedSeconds - elapsedToConsume)
            latestState = breakTimer.advance(by: elapsedToConsume)
            didAdvance = true

            if previousPhase == .rest, latestState.phase == .work {
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
    }

    private func elapsedToConsume(for state: BreakTimer.State) -> TimeInterval {
        guard pendingElapsedSeconds > 0 else {
            return 0
        }

        let availableElapsedSeconds = min(pendingElapsedSeconds, state.remainingSeconds)
        guard availableElapsedSeconds > 0 else {
            return 0
        }

        if state.remainingSeconds >= AppConfig.subsecondPrecisionThresholdSeconds {
            let wholeSeconds = floor(availableElapsedSeconds)
            return wholeSeconds > 0 ? wholeSeconds : 0
        }

        return availableElapsedSeconds
    }

    private func handle(state: BreakTimer.State) {
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
                isShowingBreak = overlayManager.showBreak(remainingSeconds: state.remainingSeconds) { [weak self] in
                    self?.skipBreak()
                }
                if isShowingBreak {
                    pendingElapsedSeconds = 0
                    lastTickUptime = currentUptime()
                }
            }
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
        consumeElapsedTime(using: breakTimer)
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

            if let activeConfig {
                breakTimer = makeBreakTimer(activeConfig)
            }
        }

        statusItemController.setRemindersPaused(false)

        if let breakTimer {
            handle(state: breakTimer.state)
        }
    }

    isolated deinit {
        cancelTick?()
    }
}

extension BreakTimer: BreakTimerControlling {
}

extension StatusItemController: StatusItemControlling {
}

@MainActor
extension BreakOverlayManager: BreakOverlayManaging {
}
