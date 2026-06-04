import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorSleepWakeRuntimeSettingsRegressionTests: XCTestCase {
    func testShortSleepDuringActiveWorkKeepsDeferredNextBreakRuntimeSettingsUpdate() {
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
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds)]
        )
        let deferredRestTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: updatedConfig.breakDurationSeconds)]
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 13_000),
            Date(timeIntervalSinceReferenceDate: 13_000 + longSleepResetThresholdSeconds - 1)
        ]
        var createdConfigs: [AppConfig] = []
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
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
            currentUptime: makeCurrentUptimeProvider([10, 10, 20, 21]),
            currentWallClockDate: makeCurrentWallClockDateProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(createdConfigs, [startupConfig, updatedConfig])
        XCTAssertEqual(initialTimer.advanceCalls, [1])
        XCTAssertEqual(deferredRestTimer.advanceCalls, [1])
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(updatedConfig.breakDurationSeconds, AppConfig.defaultBreakOverlayMessageText)]
        )
    }

    func testShortSleepDuringActiveRestKeepsDeferredPostRestRuntimeSettingsUpdate() {
        let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 1)
        let updatedConfig = AppConfig(workDurationSeconds: 600, breakDurationSeconds: 45)
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)]
        )
        let deferredWorkTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds - 9)]
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 14_000),
            Date(timeIntervalSinceReferenceDate: 14_000 + longSleepResetThresholdSeconds - 1)
        ]
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
            currentUptime: makeCurrentUptimeProvider([30, 30, 40, 41]),
            currentWallClockDate: makeCurrentWallClockDateProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(createdConfigs, [startupConfig, updatedConfig])
        XCTAssertEqual(initialTimer.advanceCalls, [1])
        XCTAssertEqual(deferredWorkTimer.advanceCalls, [9])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds),
                .active(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds),
                .active(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds - 9)
            ]
        )
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(startupConfig.breakDurationSeconds, AppConfig.defaultBreakOverlayMessageText), .hide]
        )
    }
}
