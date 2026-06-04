import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorRuntimeSettingsRegressionTests: XCTestCase {
    func testActiveBreakRuntimeSettingsUpdatesDoNotCallShowBreakAgain() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            breakOverlayMessageText: "Initial message"
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Updated message"
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeOverlayManager = FakeBreakOverlayManager()

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                FakeBreakTimer(state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([10, 11])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(fakeOverlayManager.events, [.show(20, "Initial message")])
    }

    func testActiveBreakRuntimeSettingsUpdatesDoNotHideOverlay() {
        let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let updatedConfig = AppConfig(workDurationSeconds: 600, breakDurationSeconds: 45)
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeOverlayManager = FakeBreakOverlayManager()

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                FakeBreakTimer(state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([20, 21])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertTrue(fakeOverlayManager.hasVisibleOverlayWindows)
        XCTAssertFalse(fakeOverlayManager.events.contains(.hide))
    }

    func testPauseResumeBehaviorRemainsUnchangedAfterRuntimeSettingsUpdates() throws {
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
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: 295)]
        )
        let resumedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: 599)]
        )
        var createdTimers = 0
        var scheduledTick: (() -> Void)?
        var uptime = 100.0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resumedTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: { uptime }
        )

        coordinator.start()
        uptime = 105
        scheduledTick?()

        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        runtimeSettingsStore.update(updatedConfig)
        resumeReminders()
        uptime = 106
        scheduledTick?()

        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true, false])
        XCTAssertEqual(
            fakeStatusItemController.renderedTimerTexts,
            ["05:00", "04:55", "Paused", "10:00", "09:59"]
        )
        XCTAssertEqual(initialTimer.advanceCalls, [5])
        XCTAssertEqual(resumedTimer.advanceCalls, [1])
    }

    func testStatusTimerDisplayStateRemainsAccurateAfterRuntimeDurationChanges() throws {
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
        let fakeOverlayManager = FakeBreakOverlayManager()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        let restartedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds),
            statesToReturn: [
                .init(phase: .work, remainingSeconds: 599),
                .init(phase: .rest, remainingSeconds: updatedConfig.breakDurationSeconds)
            ]
        )
        var createdTimers = 0
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : restartedTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([200, 201, 202, 203])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 300),
                .active(phase: .work, remainingSeconds: 600),
                .active(phase: .work, remainingSeconds: 599),
                .active(phase: .rest, remainingSeconds: 45)
            ]
        )
        XCTAssertEqual(
            fakeStatusItemController.renderedTimerTexts,
            ["05:00", "10:00", "09:59", "00:45"]
        )
        XCTAssertEqual(fakeOverlayManager.events, [.show(45, AppConfig.defaultBreakOverlayMessageText)])
    }

    func testIdenticalRuntimeSettingsUpdateDoesNotRecreateTimerOrDuplicateStatusUpdates() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
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
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        runtimeSettingsStore.update(startupConfig)

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(fakeStatusItemController.showsTimerStateUpdates, [true])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [.active(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)]
        )
        XCTAssertTrue(fakeOverlayManager.events.isEmpty)
        XCTAssertTrue(runtimeSettingsStore.updates.isEmpty)
    }

    func testLongSleepWakeResetUsesRuntimeSettingsStoreWithoutReloadingDiskConfig() {
        let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let runtimeEditedConfig = AppConfig(workDurationSeconds: 600, breakDurationSeconds: 45)
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: runtimeEditedConfig)
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 3)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: runtimeEditedConfig.workDurationSeconds)
        )
        var createdConfigs: [AppConfig] = []
        var loadConfigCallCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: {
                loadConfigCallCount += 1
                return startupConfig
            },
            makeBreakTimer: { config in
                createdConfigs.append(config)
                return createdConfigs.count == 1 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([100, 200, 201]),
            currentWallClockDate: makeCurrentWallClockDateProvider([
                Date(timeIntervalSinceReferenceDate: 11_000),
                Date(timeIntervalSinceReferenceDate: 11_000 + longSleepResetThresholdSeconds + 5)
            ]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(loadConfigCallCount, 0)
        XCTAssertEqual(createdConfigs, [runtimeEditedConfig, runtimeEditedConfig])
    }
}
