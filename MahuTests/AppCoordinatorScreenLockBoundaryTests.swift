import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorScreenLockBoundaryTests: XCTestCase {
    func testScreenLockWhilePausedKeepsPausedTextInsteadOfAway() throws {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let fakeTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 300))

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: config),
            loadConfig: { config },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([10, 10]),
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)

        pauseReminders()
        screenLockCallbacks.didLockScreen?()

        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true])
        XCTAssertFalse(fakeStatusItemController.statusDisplayStates.contains(.away))
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Paused"])
        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
    }

    func testScreenLockWithIconOnlyStatusItemDoesNotRenderAwayText() {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: false
        )
        let fakeStatusItemController = FakeStatusItemController()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let fakeTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 300))

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: config),
            loadConfig: { config },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([10, 10]),
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        screenLockCallbacks.didLockScreen?()

        XCTAssertEqual(fakeStatusItemController.showsTimerStateUpdates, [false])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates, [.active(phase: .work, remainingSeconds: 300), .away])
        XCTAssertTrue(fakeStatusItemController.renderedTimerTexts.isEmpty)
        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
    }

    func testScreenUnlockRearmsIdleAwaySoFreshScreenLockSamplesDoNotImmediatelyTriggerAway() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let initialTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 300))
        let screenLockResetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds),
            statesToReturn: [
                .init(phase: .work, remainingSeconds: settings.workDurationSeconds - 1),
                .init(phase: .work, remainingSeconds: settings.workDurationSeconds - 2)
            ]
        )
        let idleResetTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds))
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
                    return screenLockResetTimer
                default:
                    return idleResetTimer
                }
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 100, 101, 102, 103, 104]),
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([
                longSleepResetThresholdSeconds,
                longSleepResetThresholdSeconds,
                longSleepResetThresholdSeconds * 2
            ])
        )

        coordinator.start()
        screenLockCallbacks.didLockScreen?()
        screenLockCallbacks.didUnlockScreen?()
        scheduledTick?()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 3)
        XCTAssertEqual(screenLockResetTimer.advanceCalls, [1, 1])
        XCTAssertEqual(idleResetTimer.advanceCalls, [])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Away", "10:00", "09:59", "09:58", "Away"])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .away)
    }

    func testSleepWakeNotificationsWhileScreenLockedKeepAwaySuppressionAndStaySilent() {
        let settings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let sessionRegistrar = FakeSessionActivityObserverRegistrar()
        let screenLockCallbacks = ScreenLockCallbacks()
        let initialTimer = FakeBreakTimer(state: .init(phase: .rest, remainingSeconds: 10))
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
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([100, 100, 100, 710]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider([
                Date(timeIntervalSinceReferenceDate: 1_000),
                Date(timeIntervalSinceReferenceDate: 1_000 + longSleepResetThresholdSeconds + 5)
            ]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register,
            userAwayActivityRegistrar: makeUserAwayActivityRegistrar(
                sessionRegistrar: sessionRegistrar,
                screenLockCallbacks: screenLockCallbacks
            ),
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        screenLockCallbacks.didLockScreen?()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(createdTimers, 3)
        XCTAssertEqual(fakeSleepWakeRegistrar.willSleepCallCount, 1)
        XCTAssertEqual(fakeSleepWakeRegistrar.didWakeCallCount, 1)
        XCTAssertEqual(fakeOverlayManager.events, [.show(10, AppConfig.defaultBreakOverlayMessageText), .hide])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .away)
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:10", "Away"])
        XCTAssertEqual(resetTimer.advanceCalls, [])
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
