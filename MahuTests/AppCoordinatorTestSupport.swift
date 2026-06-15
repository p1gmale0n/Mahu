import Foundation
import XCTest
@testable import Mahu

func makeCurrentUptimeProvider(_ values: [TimeInterval]) -> () -> TimeInterval {
    var remainingValues = values
    var lastValue = values.last ?? 0

    return {
        if let nextValue = remainingValues.first {
            remainingValues.removeFirst()
            lastValue = nextValue
        }

        return lastValue
    }
}

func makeCurrentSleepAwareTimeProvider(_ values: [Date]) -> () -> TimeInterval {
    makeCurrentUptimeProvider(values.map(\.timeIntervalSinceReferenceDate))
}

final class ScriptedUserIdleTimeProvider: UserIdleTimeProviding {
    private var idleDurationSeconds: [TimeInterval]
    private let fallbackIdleDurationSeconds: TimeInterval

    init(_ idleDurationSeconds: [TimeInterval]) {
        self.idleDurationSeconds = idleDurationSeconds
        fallbackIdleDurationSeconds = idleDurationSeconds.last ?? 0
    }

    func currentIdleDurationSeconds() -> TimeInterval {
        guard idleDurationSeconds.isEmpty == false else {
            return fallbackIdleDurationSeconds
        }

        return idleDurationSeconds.removeFirst()
    }
}

final class RecordingUserIdleTimeProvider: UserIdleTimeProviding {
    private var idleDurationSeconds: [TimeInterval]
    private let fallbackIdleDurationSeconds: TimeInterval
    private(set) var queryCount = 0

    init(_ idleDurationSeconds: [TimeInterval]) {
        self.idleDurationSeconds = idleDurationSeconds
        fallbackIdleDurationSeconds = idleDurationSeconds.last ?? 0
    }

    func currentIdleDurationSeconds() -> TimeInterval {
        queryCount += 1

        guard idleDurationSeconds.isEmpty == false else {
            return fallbackIdleDurationSeconds
        }

        return idleDurationSeconds.removeFirst()
    }
}

final class FailingUserIdleTimeProvider: UserIdleTimeProviding {
    private let message: String

    init(_ message: String = "Unexpected idle query during test.") {
        self.message = message
    }

    func currentIdleDurationSeconds() -> TimeInterval {
        XCTFail(message)
        return 0
    }
}

final class CancellationSpy {
    private(set) var cancelCallCount = 0

    func cancel() {
        cancelCallCount += 1
    }
}

@MainActor
final class FakeSleepWakeObserverRegistrar {
    @MainActor
    private final class Observation {
        private let willSleep: @MainActor () -> Void
        private let didWake: @MainActor () -> Void
        private(set) var isCancelled = false

        init(
            willSleep: @escaping @MainActor () -> Void,
            didWake: @escaping @MainActor () -> Void
        ) {
            self.willSleep = willSleep
            self.didWake = didWake
        }

        func fireWillSleep() {
            guard isCancelled == false else {
                return
            }

            willSleep()
        }

        func fireDidWake() {
            guard isCancelled == false else {
                return
            }

            didWake()
        }

        func cancel() -> Bool {
            guard isCancelled == false else {
                return false
            }

            isCancelled = true
            return true
        }
    }

    private(set) var registrationCount = 0
    private(set) var willSleepCallCount = 0
    private(set) var didWakeCallCount = 0
    private(set) var cancelCount = 0
    private var observations: [Observation] = []

    func register(
        willSleep: @escaping @MainActor () -> Void,
        didWake: @escaping @MainActor () -> Void
    ) -> SleepWakeObservationCancellation {
        registrationCount += 1
        let observation = Observation(
            willSleep: { [weak self] in
                self?.willSleepCallCount += 1
                willSleep()
            },
            didWake: { [weak self] in
                self?.didWakeCallCount += 1
                didWake()
            }
        )
        observations.append(observation)

        return { [weak self, weak observation] in
            guard let self, let observation, observation.cancel() else {
                return
            }

            self.cancelCount += 1
        }
    }

    func fireWillSleep() {
        observations.last?.fireWillSleep()
    }

    func fireDidWake() {
        observations.last?.fireDidWake()
    }

    func fireAllWillSleep() {
        observations.forEach { $0.fireWillSleep() }
    }

    func fireAllDidWake() {
        observations.forEach { $0.fireDidWake() }
    }
}

@MainActor
final class FakeSessionActivityObserverRegistrar {
    @MainActor
    private final class Observation {
        private let didResignActive: @MainActor () -> Void
        private let didBecomeActive: @MainActor () -> Void
        private(set) var isCancelled = false

        init(
            didResignActive: @escaping @MainActor () -> Void,
            didBecomeActive: @escaping @MainActor () -> Void
        ) {
            self.didResignActive = didResignActive
            self.didBecomeActive = didBecomeActive
        }

        func fireDidResignActive() {
            guard isCancelled == false else {
                return
            }

            didResignActive()
        }

        func fireDidBecomeActive() {
            guard isCancelled == false else {
                return
            }

            didBecomeActive()
        }

        func cancel() -> Bool {
            guard isCancelled == false else {
                return false
            }

            isCancelled = true
            return true
        }
    }

    private(set) var registrationCount = 0
    private(set) var didResignActiveCallCount = 0
    private(set) var didBecomeActiveCallCount = 0
    private(set) var cancelCount = 0
    private var observations: [Observation] = []

    func register(
        didResignActive: @escaping @MainActor () -> Void,
        didBecomeActive: @escaping @MainActor () -> Void
    ) -> SessionActivityObservationCancellation {
        registrationCount += 1
        let observation = Observation(
            didResignActive: { [weak self] in
                self?.didResignActiveCallCount += 1
                didResignActive()
            },
            didBecomeActive: { [weak self] in
                self?.didBecomeActiveCallCount += 1
                didBecomeActive()
            }
        )
        observations.append(observation)

        return { [weak self, weak observation] in
            guard let self, let observation, observation.cancel() else {
                return
            }

            self.cancelCount += 1
        }
    }

    func fireDidResignActive() {
        observations.last?.fireDidResignActive()
    }

    func fireDidBecomeActive() {
        observations.last?.fireDidBecomeActive()
    }

    func fireAllDidResignActive() {
        observations.forEach { $0.fireDidResignActive() }
    }

    func fireAllDidBecomeActive() {
        observations.forEach { $0.fireDidBecomeActive() }
    }
}

final class FakeBreakTimer: BreakTimerControlling {
    private(set) var advanceCalls: [TimeInterval] = []
    private let statesToReturn: [BreakTimer.State]
    private let skipReturnState: BreakTimer.State
    private var currentState: BreakTimer.State
    private var stateIndex = 0

    private(set) var skipBreakCallCount = 0

    init(
        state: BreakTimer.State = .init(phase: .work, remainingSeconds: 0),
        statesToReturn: [BreakTimer.State] = [],
        skipState: BreakTimer.State? = nil
    ) {
        currentState = state
        self.statesToReturn = statesToReturn
        skipReturnState = skipState ?? state
    }

    var state: BreakTimer.State {
        currentState
    }

    func advance(by elapsedSeconds: TimeInterval) -> BreakTimer.State {
        advanceCalls.append(elapsedSeconds)

        if stateIndex < statesToReturn.count {
            currentState = statesToReturn[stateIndex]
            stateIndex += 1
        }

        return currentState
    }

    func skipBreak() -> BreakTimer.State {
        skipBreakCallCount += 1
        currentState = skipReturnState
        return currentState
    }
}

@MainActor
final class FakeLaunchAtLoginSettingsStore: LaunchAtLoginSettingsStoring {
    private(set) var launchAtLoginEnabled: Bool
    private(set) var updates: [Bool] = []
    private var observers: [UUID: (Bool) -> Void] = [:]

    init(launchAtLoginEnabled: Bool = false) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    @discardableResult
    func addObserver(_ observer: @escaping (Bool) -> Void) -> () -> Void {
        let observerID = UUID()
        observers[observerID] = observer

        return { [weak self] in
            self?.observers.removeValue(forKey: observerID)
        }
    }

    func update(_ launchAtLoginEnabled: Bool) {
        guard launchAtLoginEnabled != self.launchAtLoginEnabled else {
            return
        }

        self.launchAtLoginEnabled = launchAtLoginEnabled
        updates.append(launchAtLoginEnabled)
        let activeObservers = Array(observers.values)
        activeObservers.forEach { $0(launchAtLoginEnabled) }
    }
}

@MainActor
final class FakeLaunchAtLoginController: LaunchAtLoginSyncing {
    var syncResult = LaunchAtLoginSyncResult(action: .none, status: .disabled, warning: nil)
    private let onSync: () -> Void

    private(set) var syncCallCount = 0

    init(onSync: @escaping () -> Void = {}) {
        self.onSync = onSync
    }

    func syncDesiredState() -> LaunchAtLoginSyncResult {
        syncCallCount += 1
        onSync()
        return syncResult
    }
}

@MainActor
final class FakeStatusItemController: StatusItemControlling {
    private let statusDisplayFormatter = StatusDisplayFormatter()

    private(set) var installCallCount = 0
    private(set) var configureReminderActionsCallCount = 0
    private(set) var remindersPausedUpdates: [Bool] = []
    private(set) var showsTimerStateUpdates: [Bool] = []
    private(set) var statusDisplayStates: [StatusDisplayState] = []
    private(set) var renderedTimerTexts: [String] = []
    private(set) var pauseRemindersHandler: (() -> Void)?
    private(set) var resumeRemindersHandler: (() -> Void)?
    private(set) var showSettingsHandler: (() -> Void)?
    private(set) var clearTimerDisplayBaselinesCallCount = 0
    private(set) var resetTimerDisplayBaselinesCallCount = 0

    private var remindersPaused = false
    private var showsTimerState = false
    private var currentStatusDisplayState: StatusDisplayState?

    func install() {
        installCallCount += 1
    }

    func configureReminderActions(onPause: @escaping () -> Void, onResume: @escaping () -> Void) {
        configureReminderActionsCallCount += 1
        pauseRemindersHandler = onPause
        resumeRemindersHandler = onResume
    }

    func configureSettingsAction(_ onShowSettings: @escaping () -> Void) {
        showSettingsHandler = onShowSettings
    }

    func setRemindersPaused(_ paused: Bool) {
        remindersPaused = paused
        remindersPausedUpdates.append(paused)
        recordRenderedTimerTextIfNeeded()
    }

    func setShowsTimerState(_ showsTimerState: Bool) {
        self.showsTimerState = showsTimerState
        showsTimerStateUpdates.append(showsTimerState)
        recordRenderedTimerTextIfNeeded()
    }

    func clearTimerDisplayBaselines() {
        clearTimerDisplayBaselinesCallCount += 1
    }

    func resetTimerDisplayBaselines() {
        resetTimerDisplayBaselinesCallCount += 1
        recordRenderedTimerTextIfNeeded()
    }

    func setStatusDisplayState(_ statusDisplayState: StatusDisplayState) {
        currentStatusDisplayState = statusDisplayState
        statusDisplayStates.append(statusDisplayState)
        recordRenderedTimerTextIfNeeded()
    }

    private func recordRenderedTimerTextIfNeeded() {
        guard showsTimerState else {
            return
        }

        guard let text = currentRenderedTimerText() else {
            return
        }

        guard renderedTimerTexts.last != text else {
            return
        }

        renderedTimerTexts.append(text)
    }

    private func currentRenderedTimerText() -> String? {
        guard let currentStatusDisplayState else {
            return remindersPaused ? statusDisplayFormatter.string(for: .paused) : nil
        }

        switch currentStatusDisplayState {
        case let .active(phase, remainingSeconds):
            if remindersPaused, phase == .work {
                return statusDisplayFormatter.string(for: .paused)
            }

            return statusDisplayFormatter.string(
                for: .active(phase: phase, remainingSeconds: remainingSeconds)
            )
        case .away:
            return statusDisplayFormatter.string(for: .away)
        case .paused:
            return statusDisplayFormatter.string(for: .paused)
        }
    }
}

@MainActor
final class FakeRuntimeSettingsStore: RuntimeSettingsStoring {
    private(set) var currentSettings: AppConfig
    private(set) var updates: [AppConfig] = []
    private var observers: [UUID: (AppConfig) -> Void] = [:]

    init(currentSettings: AppConfig = .default) {
        self.currentSettings = currentSettings
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
        guard newSettings.hasSupportedSettings, newSettings != currentSettings else {
            return
        }

        currentSettings = newSettings
        updates.append(newSettings)
        let activeObservers = Array(observers.values)
        activeObservers.forEach { $0(newSettings) }
    }
}

@MainActor
final class FakeBreakCompletionSoundPlayer: BreakCompletionSoundPlaying {
    private(set) var playCallCount = 0

    func playBreakCompletionSound() {
        playCallCount += 1
    }
}

@MainActor
final class FakeBreakOverlayManager: BreakOverlayManaging {
    enum Event: Equatable {
        case show(TimeInterval, String)
        case update(TimeInterval)
        case hide
    }

    var hasActiveBreakSession = false
    var hasVisibleOverlayWindows = false {
        didSet {
            guard hasVisibleOverlayWindows != oldValue else {
                return
            }

            onVisibleOverlayWindowsChange?(hasVisibleOverlayWindows)
        }
    }
    var onVisibleOverlayWindowsChange: OverlayVisibilityChangeHandler?
    private(set) var events: [Event] = []
    private(set) var skipHandler: (() -> Void)?
    var showBreakResult = true
    var preservesActiveBreakSessionOnFailedShow = false

    func showBreak(remainingSeconds: TimeInterval, messageText: String, onSkip: @escaping () -> Void) -> Bool {
        events.append(.show(remainingSeconds, messageText))
        skipHandler = onSkip
        hasActiveBreakSession = showBreakResult || preservesActiveBreakSessionOnFailedShow
        hasVisibleOverlayWindows = showBreakResult
        return showBreakResult
    }

    func updateRemainingSeconds(_ remainingSeconds: TimeInterval) {
        events.append(.update(remainingSeconds))
    }

    func hideBreak() {
        events.append(.hide)
        skipHandler = nil
        hasActiveBreakSession = false
        hasVisibleOverlayWindows = false
    }
}
