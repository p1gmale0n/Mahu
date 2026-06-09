import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorSleepWakeAwaySuppressionTests: XCTestCase {
    func testWillSleepWhileSessionInactiveDoesNotConsumeSuppressedElapsedOrPresentBreak() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: settings.breakDurationSeconds)]
        )
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: settings),
            loadConfig: { settings },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([100, 100, 710]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider([
                Date(timeIntervalSinceReferenceDate: 1_000)
            ]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register,
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: ScriptedUserIdleTimeProvider([0])
        )

        coordinator.start()
        fakeSessionActivityRegistrar.fireDidResignActive()
        fakeSleepWakeRegistrar.fireWillSleep()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeSessionActivityRegistrar.didResignActiveCallCount, 1)
        XCTAssertEqual(fakeSleepWakeRegistrar.willSleepCallCount, 1)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertEqual(fakeOverlayManager.events, [])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .away)
    }

    func testWillSleepWhileIdleAwaySuppressionActiveDoesNotConsumeSuppressedElapsedOrPresentBreak() {
        let settings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let fakeIdleProvider = RecordingUserIdleTimeProvider([longSleepResetThresholdSeconds])
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: settings.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: settings.breakDurationSeconds)]
        )
        var scheduledTick: (() -> Void)?
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
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
            currentUptime: makeCurrentUptimeProvider([100, 101, 710]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider([
                Date(timeIntervalSinceReferenceDate: 2_000)
            ]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register,
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()
        fakeSleepWakeRegistrar.fireWillSleep()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeSleepWakeRegistrar.willSleepCallCount, 1)
        XCTAssertEqual(fakeIdleProvider.queryCount, 1)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertEqual(fakeOverlayManager.events, [])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.last, .away)
    }
}
