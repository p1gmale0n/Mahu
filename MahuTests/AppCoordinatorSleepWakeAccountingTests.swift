import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorSleepWakeAccountingTests: XCTestCase {
    func testShortSleepDuringActiveWorkPreservesElapsedAwakeTimeBeforeSleep() {
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let timer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 1_000),
            Date(timeIntervalSinceReferenceDate: 1_000 + longSleepResetThresholdSeconds - 1)
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
            currentWallClockDate: makeCurrentWallClockDateProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(timer.advanceCalls.count, 2)
        XCTAssertEqual(timer.advanceCalls[0], 1.4, accuracy: 0.000_001)
        XCTAssertEqual(timer.advanceCalls[1], 1.0, accuracy: 0.000_001)
    }

    func testShortSleepDuringActiveRestPreservesElapsedAwakeTimeBeforeSleep() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let restTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 20),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 19),
                .init(phase: .rest, remainingSeconds: 18)
            ]
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 2_000),
            Date(timeIntervalSinceReferenceDate: 2_000 + longSleepResetThresholdSeconds - 1)
        ]
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default),
            loadConfig: { .default },
            makeBreakTimer: { _ in restTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([70, 70, 71.4, 80, 81]),
            currentWallClockDate: makeCurrentWallClockDateProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(restTimer.advanceCalls.count, 2)
        XCTAssertEqual(restTimer.advanceCalls[0], 1.4, accuracy: 0.000_001)
        XCTAssertEqual(restTimer.advanceCalls[1], 1.0, accuracy: 0.000_001)
        XCTAssertEqual(
            fakeOverlayManager.events,
            [
                .show(20, AppConfig.defaultBreakOverlayMessageText),
                .update(19),
                .update(18)
            ]
        )
    }

    func testShortSleepWhilePausedDoesNotConsumeElapsedAwakeTimeBeforeSleep() {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let timer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 3_000),
            Date(timeIntervalSinceReferenceDate: 3_000 + longSleepResetThresholdSeconds - 1)
        ]

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default),
            loadConfig: { .default },
            makeBreakTimer: { _ in timer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([50, 51.4, 60, 61]),
            currentWallClockDate: makeCurrentWallClockDateProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeStatusItemController.pauseRemindersHandler?()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(timer.advanceCalls, [])
    }
}
