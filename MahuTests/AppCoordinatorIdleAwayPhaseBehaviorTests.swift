import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorIdleAwayPhaseBehaviorTests: XCTestCase {
    func testLongIdleNearExpiredActiveWorkResetsToFreshWorkWithoutPresentingBreak() {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(
                currentSettings: AppConfig(workDurationSeconds: 600, breakDurationSeconds: 20)
            ),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101]),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([longSleepResetThresholdSeconds])
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(fakeOverlayManager.events, [])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 1),
                .active(phase: .work, remainingSeconds: 600)
            ]
        )
    }

    func testLongIdleWhilePausedKeepsRemindersPausedAndResumeStartsFreshWorkInterval() {
        let fakeStatusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        let resumedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(
                currentSettings: AppConfig(workDurationSeconds: 600, breakDurationSeconds: 20)
            ),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resumedTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102]),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([longSleepResetThresholdSeconds])
        )

        coordinator.start()
        fakeStatusItemController.pauseRemindersHandler?()
        scheduledTick?()
        fakeStatusItemController.resumeRemindersHandler?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true, false])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 1),
                .active(phase: .work, remainingSeconds: 600)
            ]
        )
    }

    func testLongIdleDuringActiveRestHidesOverlaySilentlyWithoutCompletionSound() {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 10)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            runtimeSettingsStore: FakeRuntimeSettingsStore(
                currentSettings: AppConfig(workDurationSeconds: 600, breakDurationSeconds: 20)
            ),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([200, 201]),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([longSleepResetThresholdSeconds])
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(10, AppConfig.defaultBreakOverlayMessageText), .hide]
        )
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .rest, remainingSeconds: 10),
                .active(phase: .work, remainingSeconds: 600)
            ]
        )
    }

    func testShortIdlePreservesCountdownAndCurrentPhaseBehavior() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let timer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300),
            statesToReturn: [.init(phase: .work, remainingSeconds: 299)]
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default),
            loadConfig: { .default },
            makeBreakTimer: { _ in timer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([300, 301]),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([longSleepResetThresholdSeconds - 1])
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(timer.advanceCalls, [1])
        XCTAssertEqual(fakeOverlayManager.events, [])
    }

    func testIdlePollingDoesNotBreakIndependentShortSleepReconciliation() {
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let timer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 15_000),
            Date(timeIntervalSinceReferenceDate: 15_000 + longSleepResetThresholdSeconds - 1)
        ]
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default),
            loadConfig: { .default },
            makeBreakTimer: { _ in timer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([30, 31.4, 40, 41]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register,
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([0])
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(timer.advanceCalls.count, 2)
        XCTAssertEqual(timer.advanceCalls[0], 1.4, accuracy: 0.000_001)
        XCTAssertEqual(timer.advanceCalls[1], 1.0, accuracy: 0.000_001)
    }
}
