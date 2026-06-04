import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorRuntimeSettingsTests: XCTestCase {
    func testStartUsesInjectedRuntimeSettingsStoreAsStartupSourceOfTruth() {
        let expectedConfig = AppConfig(
            workDurationSeconds: 420,
            breakDurationSeconds: 30,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Runtime Store"
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: expectedConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: expectedConfig.workDurationSeconds)
        )
        var loadConfigCallCount = 0
        var scheduledInterval: TimeInterval?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: {
                loadConfigCallCount += 1
                return .default
            },
            makeBreakTimer: { config in
                XCTAssertEqual(config, expectedConfig)
                return fakeTimer
            },
            scheduleRepeatingTick: { interval, _ in
                scheduledInterval = interval
                return {}
            }
        )

        coordinator.start()

        XCTAssertEqual(loadConfigCallCount, 0)
        XCTAssertEqual(fakeStatusItemController.installCallCount, 1)
        XCTAssertEqual(fakeStatusItemController.showsTimerStateUpdates, [true])
        XCTAssertEqual(scheduledInterval, 1)
        XCTAssertTrue(fakeOverlayManager.events.isEmpty)
    }

    func testLoadConfigRunsOnlyOnceAcrossStartupTicksAndRuntimeSettingUpdates() {
        let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let runtimeEditedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeRuntimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [
                .init(phase: .work, remainingSeconds: 299),
                .init(phase: .work, remainingSeconds: 298)
            ]
        )
        var loadConfigCallCount = 0
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([10, 11, 12])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: fakeRuntimeSettingsStore,
            loadConfig: {
                loadConfigCallCount += 1
                return .default
            },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: currentUptime
        )

        coordinator.start()
        scheduledTick?()
        fakeRuntimeSettingsStore.update(runtimeEditedConfig)
        scheduledTick?()

        XCTAssertEqual(loadConfigCallCount, 0)
        XCTAssertEqual(fakeTimer.advanceCalls, [1, 1])
    }

    func testLoadConfigRunsOnceWhenCoordinatorCreatesRuntimeSettingsStore() {
        let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: 299)]
        )
        var loadConfigCallCount = 0
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([100, 101])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: {
                loadConfigCallCount += 1
                return startupConfig
            },
            makeBreakTimer: { config in
                XCTAssertEqual(config, startupConfig)
                return fakeTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: currentUptime
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(loadConfigCallCount, 1)
        XCTAssertEqual(fakeTimer.advanceCalls, [1])
    }

    func testRuntimeWorkDurationChangeDuringActiveWorkStartsFreshWorkIntervalFromNewDuration() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        let restartedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: 599)]
        )
        var createdConfigs: [AppConfig] = []
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { config in
                createdConfigs.append(config)
                return createdConfigs.count == 1 ? initialTimer : restartedTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([10, 11, 12])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)
        scheduledTick?()

        XCTAssertEqual(createdConfigs, [startupConfig, updatedConfig])
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(restartedTimer.advanceCalls, [1])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 300),
                .active(phase: .work, remainingSeconds: 600),
                .active(phase: .work, remainingSeconds: 599)
            ]
        )
    }

    func testRuntimeBreakDurationChangeDuringActiveWorkAppliesAtNextBreakWithoutResettingCurrentWork() {
        let startupConfig = AppConfig(
            workDurationSeconds: 1,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 1,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds)]
        )
        let deferredRestTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: updatedConfig.breakDurationSeconds)]
        )
        var createdConfigs: [AppConfig] = []
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { config in
                createdConfigs.append(config)
                return createdConfigs.count == 1 ? initialTimer : deferredRestTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([20, 21, 22])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)
        scheduledTick?()

        XCTAssertEqual(createdConfigs, [startupConfig, updatedConfig])
        XCTAssertEqual(initialTimer.advanceCalls, [1])
        XCTAssertEqual(deferredRestTimer.advanceCalls, [1])
        XCTAssertEqual(fakeOverlayManager.events, [.show(45, AppConfig.defaultBreakOverlayMessageText)])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 1),
                .active(phase: .rest, remainingSeconds: 45)
            ]
        )
    }

    func testRuntimeDurationChangesDuringActiveRestDoNotReplaceCurrentBreakOrSkipHandler() throws {
        let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let updatedConfig = AppConfig(workDurationSeconds: 600, breakDurationSeconds: 45)
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds),
            skipState: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return fakeTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([30, 31])
        )

        coordinator.start()
        let skipBreak = try XCTUnwrap(fakeOverlayManager.skipHandler)
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText)])

        skipBreak()

        XCTAssertEqual(fakeTimer.skipBreakCallCount, 1)
        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText), .hide])
    }

    func testRuntimeDurationChangesDuringActiveRestApplyAfterRestCompletesOrIsSkipped() throws {
        do {
            let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 1)
            let updatedConfig = AppConfig(workDurationSeconds: 600, breakDurationSeconds: 45)
            let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
            let fakeStatusItemController = FakeStatusItemController()
            let fakeOverlayManager = FakeBreakOverlayManager()
            let initialTimer = FakeBreakTimer(
                state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds),
                statesToReturn: [.init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)]
            )
            let deferredWorkTimer = FakeBreakTimer(
                state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds)
            )
            var createdConfigs: [AppConfig] = []
            var scheduledTick: (() -> Void)?

            let coordinator = AppCoordinator(
                statusItemController: fakeStatusItemController,
                overlayManager: fakeOverlayManager,
                runtimeSettingsStore: runtimeSettingsStore,
                loadConfig: { startupConfig },
                makeBreakTimer: { config in
                    createdConfigs.append(config)
                    return createdConfigs.count == 1 ? initialTimer : deferredWorkTimer
                },
                scheduleRepeatingTick: { _, tick in
                    scheduledTick = tick
                    return {}
                },
            currentUptime: makeCurrentUptimeProvider([40, 41, 42])
        )

            coordinator.start()
            runtimeSettingsStore.update(updatedConfig)
            scheduledTick?()

            XCTAssertEqual(createdConfigs, [startupConfig, updatedConfig])
            XCTAssertEqual(
                fakeStatusItemController.statusDisplayStates,
                [
                    .active(phase: .rest, remainingSeconds: 1),
                    .active(phase: .work, remainingSeconds: 600)
                ]
            )
            XCTAssertEqual(fakeOverlayManager.events, [.show(1, AppConfig.defaultBreakOverlayMessageText), .hide])
        }

        do {
            let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
            let updatedConfig = AppConfig(workDurationSeconds: 900, breakDurationSeconds: 30)
            let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
            let fakeStatusItemController = FakeStatusItemController()
            let fakeOverlayManager = FakeBreakOverlayManager()
            let initialTimer = FakeBreakTimer(
                state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds),
                skipState: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
            )
            let deferredWorkTimer = FakeBreakTimer(
                state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds)
            )
            var createdConfigs: [AppConfig] = []

            let coordinator = AppCoordinator(
                statusItemController: fakeStatusItemController,
                overlayManager: fakeOverlayManager,
                runtimeSettingsStore: runtimeSettingsStore,
                loadConfig: { startupConfig },
                makeBreakTimer: { config in
                    createdConfigs.append(config)
                    return createdConfigs.count == 1 ? initialTimer : deferredWorkTimer
                },
                scheduleRepeatingTick: { _, _ in {} },
                currentUptime: makeCurrentUptimeProvider([50, 51])
            )

            coordinator.start()
            runtimeSettingsStore.update(updatedConfig)
            let skipBreak = try XCTUnwrap(fakeOverlayManager.skipHandler)
            skipBreak()

            XCTAssertEqual(createdConfigs, [startupConfig, updatedConfig])
            XCTAssertEqual(
                fakeStatusItemController.statusDisplayStates,
                [
                    .active(phase: .rest, remainingSeconds: 20),
                    .active(phase: .work, remainingSeconds: 900)
                ]
            )
            XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText), .hide])
        }
    }
}
