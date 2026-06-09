import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorScreenLockAwayTests: XCTestCase {
    func testScreenLockSuppressesNearExpiredWorkBoundaryWithoutOverlayOrCompletionSound() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let initialTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 1))
        let resetTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds))
        let fakeIdleProvider = RecordingUserIdleTimeProvider([999])
        var scheduledTick: (() -> Void)?
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: settings),
            loadConfig: { settings },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 100, 900]),
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        screenLockCallbacks.didLockScreen?()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeIdleProvider.queryCount, 0)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertEqual(fakeOverlayManager.events, [])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Away"])
    }

    func testScreenLockDuringActiveRestClosesOverlaySilentlyAndResetsToFreshWork() {
        let settings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let restTimer = FakeBreakTimer(state: .init(phase: .rest, remainingSeconds: 4))
        let resetTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds))
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: settings),
            loadConfig: { settings },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? restTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([200, 200, 201]),
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        screenLockCallbacks.didLockScreen?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(restTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(4, AppConfig.defaultBreakOverlayMessageText), .hide]
        )
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:04", "Away"])
    }

    func testRepeatedLockedTicksDoNotConsumeElapsedOrQueryIdleProviderThroughScreenLockPath() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 5,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let initialTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 1))
        let resetTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds))
        let fakeIdleProvider = RecordingUserIdleTimeProvider([999, 999])
        var scheduledTick: (() -> Void)?
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: settings),
            loadConfig: { settings },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([300, 300, 310, 340]),
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        screenLockCallbacks.didLockScreen?()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeIdleProvider.queryCount, 0)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Away"])
    }

    func testScreenUnlockClearsAwayRefreshesBaselineAndDoesNotConsumeLockedDuration() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let initialTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 1))
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: settings.workDurationSeconds - 1)]
        )
        var scheduledTick: (() -> Void)?
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: settings),
            loadConfig: { settings },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 100, 150, 151]),
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        screenLockCallbacks.didLockScreen?()
        screenLockCallbacks.didUnlockScreen?()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [1])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Away", "10:00", "09:59"])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .active(phase: .work, remainingSeconds: 599))
    }

    func testDuplicateSessionSwitchAndScreenLockEventsDoNotDoubleResetOrRegressTrayState() {
        let settings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let initialTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 1))
        let resetTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds))
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: settings),
            loadConfig: { settings },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([100, 100, 101]),
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        sessionRegistrar.fireDidResignActive()
        screenLockCallbacks.didLockScreen?()
        sessionRegistrar.fireDidBecomeActive()
        screenLockCallbacks.didUnlockScreen?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(sessionRegistrar.didResignActiveCallCount, 1)
        XCTAssertEqual(sessionRegistrar.didBecomeActiveCallCount, 1)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Away", "05:00"])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .active(phase: .work, remainingSeconds: 300))
    }
}

@MainActor
private final class ScreenLockCallbacks {
    var didLockScreen: (@MainActor () -> Void)?
    var didUnlockScreen: (@MainActor () -> Void)?
}

@MainActor
private func makeUserAwayActivityRegistrar(
    sessionRegistrar: FakeSessionActivityObserverRegistrar,
    screenLockCallbacks: ScreenLockCallbacks
) -> UserAwayActivityObservationRegistrar {
    { didBecomeAway, didBecomeActive in
        let cancelSessionActivity = sessionRegistrar.register(
            didResignActive: didBecomeAway,
            didBecomeActive: didBecomeActive
        )
        screenLockCallbacks.didLockScreen = didBecomeAway
        screenLockCallbacks.didUnlockScreen = didBecomeActive

        return {
            cancelSessionActivity()
            screenLockCallbacks.didLockScreen = nil
            screenLockCallbacks.didUnlockScreen = nil
        }
    }
}
