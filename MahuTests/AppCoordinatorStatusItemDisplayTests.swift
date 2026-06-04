import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorStatusItemDisplayTests: XCTestCase {
    func testStartWithTimerDisplayEnabledSendsInitialWorkRemainingState() {
        let expectedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 15,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: expectedConfig.workDurationSeconds)
        )

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { expectedConfig },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()

        XCTAssertEqual(fakeStatusItemController.showsTimerStateUpdates, [true])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [.active(phase: .work, remainingSeconds: 300)]
        )
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00"])
    }

    func testWorkTicksUpdateStatusItemTimerTextWhenTimerDisplayIsEnabled() {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300),
            statesToReturn: [.init(phase: .work, remainingSeconds: 299)]
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([10, 11])

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { config },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: currentUptime
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 300),
                .active(phase: .work, remainingSeconds: 299)
            ]
        )
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "04:59"])
    }

    func testRestPhaseUpdatesStatusItemTimerTextTogetherWithOverlayUpdates() {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 20),
                .init(phase: .rest, remainingSeconds: 19)
            ]
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([100, 101, 101, 102])

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            loadConfig: { config },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: currentUptime
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText), .update(19)])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 1),
                .active(phase: .rest, remainingSeconds: 20),
                .active(phase: .rest, remainingSeconds: 19)
            ]
        )
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:01", "00:20", "00:19"])
    }

    func testSkipAndNaturalBreakCompletionUpdateStatusDisplayToNextWorkInterval() {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )

        do {
            let fakeStatusItemController = FakeStatusItemController()
            let fakeOverlayManager = FakeBreakOverlayManager()
            let fakeTimer = FakeBreakTimer(
                state: .init(phase: .work, remainingSeconds: 1),
                statesToReturn: [.init(phase: .rest, remainingSeconds: 20)],
                skipState: .init(phase: .work, remainingSeconds: 300)
            )
            var scheduledTick: (() -> Void)?
            let currentUptime = makeCurrentUptimeProvider([30, 31, 31])

            let coordinator = AppCoordinator(
                statusItemController: fakeStatusItemController,
                overlayManager: fakeOverlayManager,
                loadConfig: { config },
                makeBreakTimer: { _ in fakeTimer },
                scheduleRepeatingTick: { _, tick in
                    scheduledTick = tick
                    return {}
                },
                currentUptime: currentUptime
            )

            coordinator.start()
            scheduledTick?()
            fakeOverlayManager.skipHandler?()

            XCTAssertEqual(
                fakeStatusItemController.statusDisplayStates,
                [
                    .active(phase: .work, remainingSeconds: 1),
                    .active(phase: .rest, remainingSeconds: 20),
                    .active(phase: .work, remainingSeconds: 300)
                ]
            )
        }

        do {
            let fakeStatusItemController = FakeStatusItemController()
            let fakeOverlayManager = FakeBreakOverlayManager()
            let fakeTimer = FakeBreakTimer(
                state: .init(phase: .work, remainingSeconds: 1),
                statesToReturn: [
                    .init(phase: .rest, remainingSeconds: 1),
                    .init(phase: .work, remainingSeconds: 300)
                ]
            )
            var scheduledTick: (() -> Void)?
            let currentUptime = makeCurrentUptimeProvider([40, 41, 41, 42])

            let coordinator = AppCoordinator(
                statusItemController: fakeStatusItemController,
                overlayManager: fakeOverlayManager,
                loadConfig: { config },
                makeBreakTimer: { _ in fakeTimer },
                scheduleRepeatingTick: { _, tick in
                    scheduledTick = tick
                    return {}
                },
                currentUptime: currentUptime
            )

            coordinator.start()
            scheduledTick?()
            scheduledTick?()

            XCTAssertEqual(
                fakeStatusItemController.statusDisplayStates,
                [
                    .active(phase: .work, remainingSeconds: 1),
                    .active(phase: .rest, remainingSeconds: 1),
                    .active(phase: .work, remainingSeconds: 300)
                ]
            )
        }
    }

    func testRuntimeTimerDisplayToggleAppliesImmediatelyAndPreservesCurrentTimerText() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: 299)]
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([10, 11])
        )

        coordinator.start()

        runtimeSettingsStore.update(
            AppConfig(
                workDurationSeconds: 300,
                breakDurationSeconds: 20,
                showStatusItemTimerState: true
            )
        )
        scheduledTick?()

        XCTAssertEqual(fakeStatusItemController.showsTimerStateUpdates, [false, true])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "04:59"])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 300),
                .active(phase: .work, remainingSeconds: 299)
            ]
        )
    }

    func testRuntimeTimerDisplayToggleDoesNotRecreateTimerOrOverlay() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds)
        )
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return fakeTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([20, 21])
        )

        coordinator.start()

        runtimeSettingsStore.update(
            AppConfig(
                workDurationSeconds: 300,
                breakDurationSeconds: 20,
                showStatusItemTimerState: true
            )
        )
        runtimeSettingsStore.update(startupConfig)

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText)])
        XCTAssertEqual(fakeStatusItemController.showsTimerStateUpdates, [false, true, false])
    }

    func testLongSleepWakeResetUpdatesStatusItemTimerDisplayToFreshWorkDuration() {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 2)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: config.workDurationSeconds)
        )
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: config),
            loadConfig: { config },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return timerCreationCount == 1 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([50, 50, 501]),
            currentWallClockDate: makeCurrentWallClockDateProvider([
                Date(timeIntervalSinceReferenceDate: 12_000),
                Date(timeIntervalSinceReferenceDate: 12_000 + longSleepResetThresholdSeconds + 3)
            ]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 2),
                .active(phase: .work, remainingSeconds: 300)
            ]
        )
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:02", "05:00"])
    }
}
