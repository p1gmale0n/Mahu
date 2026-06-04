import Foundation
import OSLog

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
    func setShowsTimerState(_ showsTimerState: Bool)
    func setStatusDisplayState(_ statusDisplayState: StatusDisplayState)
}

@MainActor
protocol RuntimeSettingsStoring: AnyObject {
    var currentSettings: AppConfig { get }

    @discardableResult
    func addObserver(_ observer: @escaping (AppConfig) -> Void) -> () -> Void

    func update(_ newSettings: AppConfig)
}

typealias RepeatingTickScheduler = (TimeInterval, @escaping () -> Void) -> () -> Void
typealias CurrentUptimeProvider = () -> TimeInterval
typealias CurrentWallClockDateProvider = () -> Date
typealias OverlayVisibilityChangeHandler = (Bool) -> Void

let longSleepResetThresholdSeconds: TimeInterval = 300

enum RuntimeSettingsScheduleUpdateAction {
    case none
    case restartActiveWorkImmediately
    case applyAtNextBreak
    case applyAfterCurrentRestEnds
}

func runtimeSettingsScheduleUpdateAction(
    previousSettings: AppConfig,
    newSettings: AppConfig,
    currentPhase: BreakTimer.Phase,
    remindersPaused: Bool
) -> RuntimeSettingsScheduleUpdateAction {
    let workDurationChanged = previousSettings.workDurationSeconds != newSettings.workDurationSeconds
    let breakDurationChanged = previousSettings.breakDurationSeconds != newSettings.breakDurationSeconds

    guard workDurationChanged || breakDurationChanged else {
        return .none
    }

    switch currentPhase {
    case .work:
        if remindersPaused {
            return .none
        }

        return workDurationChanged ? .restartActiveWorkImmediately : .applyAtNextBreak
    case .rest:
        return .applyAfterCurrentRestEnds
    }
}

enum RuntimeSettingsChangeDirective {
    case none
    case restartActiveWork(AppConfig)
}

enum PendingRuntimeSettingsDirective {
    case keep(BreakTimer.State)
    case replaceTimerAndAdvanceToRest(AppConfig)
    case replaceTimerAfterRest(AppConfig)
}

enum WakeReconciliationAction {
    case none
    case preservePausedWork
    case resetActiveWork
    case resetAfterActiveRest
}

struct RuntimeSettingsApplicationPolicy {
    private var observedSettings: AppConfig?
    private var pendingAction: (action: RuntimeSettingsScheduleUpdateAction, settings: AppConfig)?

    mutating func reset(startupSettings: AppConfig) {
        observedSettings = startupSettings
        pendingAction = nil
    }

    mutating func handleChange(
        _ newSettings: AppConfig,
        currentPhase: BreakTimer.Phase?,
        remindersPaused: Bool
    ) -> RuntimeSettingsChangeDirective {
        let previousSettings = observedSettings ?? newSettings
        observedSettings = newSettings

        guard let currentPhase else {
            return .none
        }

        let scheduleUpdateAction = runtimeSettingsScheduleUpdateAction(
            previousSettings: previousSettings,
            newSettings: newSettings,
            currentPhase: currentPhase,
            remindersPaused: remindersPaused
        )

        switch scheduleUpdateAction {
        case .none:
            if remindersPaused, durationsChanged(from: previousSettings, to: newSettings) {
                pendingAction = nil
            }
            return .none
        case .restartActiveWorkImmediately:
            pendingAction = nil
            return .restartActiveWork(newSettings)
        case .applyAtNextBreak, .applyAfterCurrentRestEnds:
            pendingAction = (scheduleUpdateAction, newSettings)
            return .none
        }
    }

    mutating func applyPendingIfNeeded(to state: BreakTimer.State) -> PendingRuntimeSettingsDirective {
        guard let pendingAction else {
            return .keep(state)
        }

        switch pendingAction.action {
        case .applyAtNextBreak where state.phase == .rest:
            self.pendingAction = nil
            return .replaceTimerAndAdvanceToRest(pendingAction.settings)
        case .applyAfterCurrentRestEnds where state.phase == .work:
            self.pendingAction = nil
            return .replaceTimerAfterRest(pendingAction.settings)
        default:
            return .keep(state)
        }
    }

    private func durationsChanged(from previousSettings: AppConfig, to newSettings: AppConfig) -> Bool {
        previousSettings.workDurationSeconds != newSettings.workDurationSeconds ||
            previousSettings.breakDurationSeconds != newSettings.breakDurationSeconds
    }
}

func elapsedTimeToConsume(
    pendingElapsedSeconds: TimeInterval,
    for state: BreakTimer.State
) -> TimeInterval {
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

func wakeReconciliationAction(
    sleepStartedAt: Date?,
    wokeAt: Date,
    currentState: BreakTimer.State?,
    remindersPaused: Bool,
    longSleepThresholdSeconds: TimeInterval = longSleepResetThresholdSeconds
) -> WakeReconciliationAction {
    guard let sleepStartedAt,
          let currentState else {
        return .none
    }

    guard max(0, wokeAt.timeIntervalSince(sleepStartedAt)) >= longSleepThresholdSeconds else {
        return .none
    }

    switch currentState.phase {
    case .work:
        return remindersPaused ? .preservePausedWork : .resetActiveWork
    case .rest:
        return .resetAfterActiveRest
    }
}

@MainActor
final class RuntimeSettingsStore: RuntimeSettingsStoring {
    private static let logger = Logger(subsystem: "Mahu", category: "RuntimeSettingsStore")

    private(set) var currentSettings: AppConfig
    private var observers: [UUID: (AppConfig) -> Void] = [:]

    init(initialSettings: AppConfig = .default) {
        currentSettings = initialSettings
    }

    @discardableResult
    func addObserver(_ observer: @escaping (AppConfig) -> Void) -> () -> Void {
        let observerID = UUID()
        observers[observerID] = observer

        return { [weak self] in
            self?.observers.removeValue(forKey: observerID)
        }
    }

    func update(_ newSettings: AppConfig) {
        guard newSettings.hasSupportedDurations else {
            Self.logger.warning(
                "Ignoring runtime settings update because durations must be finite, between \(Int(AppConfig.minimumSupportedDurationSeconds)) and \(Int64(AppConfig.maximumSupportedDurationSeconds)) seconds, and small enough to preserve one-second timer precision."
            )
            return
        }

        guard newSettings != currentSettings else {
            return
        }

        currentSettings = newSettings
        let activeObservers = Array(observers.values)
        activeObservers.forEach { $0(newSettings) }
    }
}

@MainActor
protocol BreakOverlayManaging: AnyObject {
    var hasActiveBreakSession: Bool { get }
    var hasVisibleOverlayWindows: Bool { get }
    var onVisibleOverlayWindowsChange: OverlayVisibilityChangeHandler? { get set }
    @discardableResult
    func showBreak(remainingSeconds: TimeInterval, messageText: String, onSkip: @escaping () -> Void) -> Bool
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

extension BreakTimer: BreakTimerControlling {
}

extension StatusItemController: StatusItemControlling {
}

@MainActor
extension BreakOverlayManager: BreakOverlayManaging {
}
