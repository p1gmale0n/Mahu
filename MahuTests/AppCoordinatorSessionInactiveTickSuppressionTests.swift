import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorSessionInactiveTickSuppressionTests: XCTestCase {
    func testRepeatedTicksWhileSessionInactiveDoNotConsumeElapsedOrQueryIdleProvider() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 5,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds)
        )
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
            currentUptime: makeCurrentUptimeProvider([100, 100, 110, 140]),
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        fakeSessionActivityRegistrar.fireDidResignActive()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeSessionActivityRegistrar.didResignActiveCallCount, 1)
        XCTAssertEqual(fakeIdleProvider.queryCount, 0)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Away"])
    }

    func testSessionInactiveSuppressesBoundaryCrossingWithoutOverlayOrSoundWhenIdleAwayDisabled() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false
        )
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: settings.breakDurationSeconds)]
        )
        let fakeIdleProvider = RecordingUserIdleTimeProvider([999])
        var scheduledTick: (() -> Void)?
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
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
            currentUptime: makeCurrentUptimeProvider([200, 200, 900]),
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        fakeSessionActivityRegistrar.fireDidResignActive()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeIdleProvider.queryCount, 0)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertEqual(fakeOverlayManager.events, [])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testSessionActiveClearsAwayRefreshesBaselineAndDoesNotConsumeLockedDurationOnNextTick() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
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
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        fakeSessionActivityRegistrar.fireDidResignActive()
        fakeSessionActivityRegistrar.fireDidBecomeActive()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeSessionActivityRegistrar.didResignActiveCallCount, 1)
        XCTAssertEqual(fakeSessionActivityRegistrar.didBecomeActiveCallCount, 1)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [1])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Away", "10:00", "09:59"])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .active(phase: .work, remainingSeconds: 599))
    }

    func testSessionActiveWithoutPriorInactiveIsNonDestructive() {
        let settings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let timer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: settings),
            loadConfig: { settings },
            makeBreakTimer: { _ in timer },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([100]),
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        fakeSessionActivityRegistrar.fireDidBecomeActive()

        XCTAssertEqual(fakeSessionActivityRegistrar.didResignActiveCallCount, 0)
        XCTAssertEqual(fakeSessionActivityRegistrar.didBecomeActiveCallCount, 1)
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates, [.active(phase: .work, remainingSeconds: 300)])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00"])
        XCTAssertEqual(timer.advanceCalls, [])
    }

    func testSessionUnlockRearmsIdleAwaySoFreshSessionSamplesDoNotImmediatelyTriggerAway() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let sessionResetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds),
            statesToReturn: [
                .init(phase: .work, remainingSeconds: settings.workDurationSeconds - 1),
                .init(phase: .work, remainingSeconds: settings.workDurationSeconds - 2)
            ]
        )
        let idleResetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds)
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
                switch createdTimers {
                case 0:
                    return initialTimer
                case 1:
                    return sessionResetTimer
                default:
                    return idleResetTimer
                }
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 100, 101, 102, 103, 104]),
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([
                longSleepResetThresholdSeconds,
                longSleepResetThresholdSeconds,
                longSleepResetThresholdSeconds * 2
            ])
        )

        coordinator.start()
        fakeSessionActivityRegistrar.fireDidResignActive()
        fakeSessionActivityRegistrar.fireDidBecomeActive()
        scheduledTick?()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 3)
        XCTAssertEqual(sessionResetTimer.advanceCalls, [1, 1])
        XCTAssertEqual(idleResetTimer.advanceCalls, [])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Away", "10:00", "09:59", "09:58", "Away"])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .away)
    }

    func testCoordinatorStartedInactiveResetsToFreshWorkAndShowsAwayWithoutActiveRender() {
        let settings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds)
        )
        var createdTimers = 0
        var scheduledTickCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: settings),
            loadConfig: { settings },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in
                scheduledTickCount += 1
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 100, 101]),
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start(initialUserIsActive: false)

        XCTAssertEqual(fakeStatusItemController.installCallCount, 1)
        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(scheduledTickCount, 1)
        XCTAssertEqual(fakeOverlayManager.events, [])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .away)
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["Away"])
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
    }

    func testDuplicateAwayEventsFromSessionSwitchAndScreenLockDoNotResetFreshWorkMoreThanOnce() {
        let settings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        var didLockScreen: (@MainActor () -> Void)?
        var didUnlockScreen: (@MainActor () -> Void)?
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds)
        )
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
            userAwayActivityRegistrar: { didBecomeAway, didBecomeActive in
                let cancelSessionActivity = fakeSessionActivityRegistrar.register(
                    didResignActive: didBecomeAway,
                    didBecomeActive: didBecomeActive
                )
                didLockScreen = didBecomeAway
                didUnlockScreen = didBecomeActive

                return {
                    cancelSessionActivity()
                    didLockScreen = nil
                    didUnlockScreen = nil
                }
            },
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        fakeSessionActivityRegistrar.fireDidResignActive()
        didLockScreen?()
        fakeSessionActivityRegistrar.fireDidBecomeActive()
        didUnlockScreen?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeSessionActivityRegistrar.didResignActiveCallCount, 1)
        XCTAssertEqual(fakeSessionActivityRegistrar.didBecomeActiveCallCount, 1)
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Away", "05:00"])
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
    }
}
