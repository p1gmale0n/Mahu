import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorIdleAwayPhaseBehaviorTests: XCTestCase {
    func testLongIdleNearExpiredActiveWorkResetsToFreshWorkWithoutPresentingBreak() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
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
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
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
                .away
            ]
        )
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Away"])
    }

    func testLongIdleWhilePausedKeepsRemindersPausedAndResumeStartsFreshWorkInterval() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
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
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
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
        XCTAssertFalse(fakeStatusItemController.statusDisplayStates.contains(.away))
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "Paused", "10:00"])
    }

    func testLongIdleDuringActiveRestHidesOverlaySilentlyWithoutCompletionSound() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
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
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
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
                .away
            ]
        )
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:10", "Away"])
    }

    func testLongIdleAwayShowsAwayAndKeepsAwayWhileSuppressionRemainsActive() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102]),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([
                longSleepResetThresholdSeconds,
                longSleepResetThresholdSeconds + 1
            ])
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates, [
            .active(phase: .work, remainingSeconds: 300),
            .away,
            .away
        ])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Away"])
    }

    func testIdleActivityBelowThresholdExitsAwayRearmsResetAndRestoresCountdownDisplay() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let firstResetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600),
            statesToReturn: [.init(phase: .work, remainingSeconds: 599)]
        )
        let secondResetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                switch timerCreationCount {
                case 0:
                    return initialTimer
                case 1:
                    return firstResetTimer
                default:
                    return secondResetTimer
                }
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102, 103]),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([
                longSleepResetThresholdSeconds,
                longSleepResetThresholdSeconds - 1,
                longSleepResetThresholdSeconds
            ])
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 3)
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Away", "10:00", "09:59", "Away"])
    }

    func testDisabledIdleAwayNeverShowsAwayEvenAfterProviderWouldReportLongIdle() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
        let disabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: enabledSettings)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeIdleProvider = RecordingUserIdleTimeProvider([
            longSleepResetThresholdSeconds,
            longSleepResetThresholdSeconds
        ])
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let firstResetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600),
            statesToReturn: [.init(phase: .work, remainingSeconds: 599)]
        )
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : firstResetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()
        runtimeSettingsStore.update(disabledSettings)
        scheduledTick?()

        XCTAssertEqual(fakeIdleProvider.queryCount, 1)
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Away", "10:00", "09:59"])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .active(phase: .work, remainingSeconds: 599))
    }

    func testPausedWorkRemainsDistinctFromAwayDuringLongIdle() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let timer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { .default },
            makeBreakTimer: { _ in timer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101]),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([longSleepResetThresholdSeconds])
        )

        coordinator.start()
        fakeStatusItemController.pauseRemindersHandler?()
        scheduledTick?()

        XCTAssertFalse(fakeStatusItemController.statusDisplayStates.contains(.away))
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Paused"])
        XCTAssertEqual(timer.advanceCalls, [])
    }

    func testShortIdlePreservesCountdownAndCurrentPhaseBehavior() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeStatusItemController = FakeStatusItemController()
        let fakeIdleProvider = RecordingUserIdleTimeProvider([longSleepResetThresholdSeconds - 1])
        let timer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300),
            statesToReturn: [.init(phase: .work, remainingSeconds: 299)]
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { enabledSettings },
            makeBreakTimer: { _ in timer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([300, 301]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(fakeIdleProvider.queryCount, 1)
        XCTAssertFalse(fakeStatusItemController.statusDisplayStates.contains(.away))
        XCTAssertEqual(timer.advanceCalls, [1])
        XCTAssertEqual(fakeOverlayManager.events, [])
    }

    func testIdlePollingDoesNotBreakIndependentShortSleepReconciliation() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true
        )
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let fakeIdleProvider = RecordingUserIdleTimeProvider([0])
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
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { enabledSettings },
            makeBreakTimer: { _ in timer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([30, 31.4, 40, 41]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register,
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(fakeIdleProvider.queryCount, 1)
        XCTAssertEqual(timer.advanceCalls.count, 2)
        XCTAssertEqual(timer.advanceCalls[0], 1.4, accuracy: 0.000_001)
        XCTAssertEqual(timer.advanceCalls[1], 1.0, accuracy: 0.000_001)
    }
}
