import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorStatusItemRecoveryBaselineTests: XCTestCase {
    func testLongIdleDuringActiveRestWithDeferredRuntimeDurationChangeClearsBaselinesBeforeFreshWorkRenders() {
        let startupConfig = AppConfig(
            workDurationSeconds: 60_000,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 59,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = SequencingStatusItemControllerSpy()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds)
        )
        let restartedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds)
        )
        var createdConfigs: [AppConfig] = []
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
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
            currentUptime: makeCurrentUptimeProvider([100, 100, 101, 101]),
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([longSleepResetThresholdSeconds])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)
        scheduledTick?()

        XCTAssertEqual(createdConfigs, [startupConfig, updatedConfig])
        XCTAssertEqual(statusItemController.clearTimerDisplayBaselinesCallCount, 1)
        XCTAssertEqual(statusItemController.resetTimerDisplayBaselinesCallCount, 0)
        XCTAssertEqual(
            statusItemController.events,
            [
                .setShowsTimerState(true),
                .render("00:20"),
                .clearTimerDisplayBaselines,
                .render("00:59")
            ]
        )
    }

    func testLongSleepDuringActiveRestWithDeferredRuntimeDurationChangeClearsBaselinesBeforeFreshWorkRenders() {
        let startupConfig = AppConfig(
            workDurationSeconds: 60_000,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 59,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = SequencingStatusItemControllerSpy()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds)
        )
        let restartedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 1_000),
            Date(timeIntervalSinceReferenceDate: 1_000 + longSleepResetThresholdSeconds + 5)
        ]
        var createdConfigs: [AppConfig] = []

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { config in
                createdConfigs.append(config)
                return createdConfigs.count == 1 ? initialTimer : restartedTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([10, 10, 10, 10, 10]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register,
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([0])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(createdConfigs, [startupConfig, updatedConfig])
        XCTAssertEqual(statusItemController.clearTimerDisplayBaselinesCallCount, 1)
        XCTAssertEqual(statusItemController.resetTimerDisplayBaselinesCallCount, 0)
        XCTAssertEqual(
            statusItemController.events,
            [
                .setShowsTimerState(true),
                .render("00:20"),
                .clearTimerDisplayBaselines,
                .render("00:59")
            ]
        )
    }
}
