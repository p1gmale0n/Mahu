import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func testStartInstallsStatusItemLoadsConfigCreatesTimerAndSchedulesTicker() {
        let expectedConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 15)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: expectedConfig.workDurationSeconds)
        )
        var didLoadConfig = false
        var scheduledInterval: TimeInterval?
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([100, 101])

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            loadConfig: {
                didLoadConfig = true
                return expectedConfig
            },
            makeBreakTimer: { config in
                XCTAssertEqual(config, expectedConfig)
                return fakeTimer
            },
            scheduleRepeatingTick: { interval, tick in
                scheduledInterval = interval
                scheduledTick = tick
                return {}
            },
            currentUptime: currentUptime
        )

        coordinator.start()

        XCTAssertEqual(fakeStatusItemController.installCallCount, 1)
        XCTAssertTrue(didLoadConfig)
        XCTAssertEqual(scheduledInterval, 1)
        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
        XCTAssertTrue(fakeOverlayManager.events.isEmpty)

        scheduledTick?()

        XCTAssertEqual(fakeTimer.advanceCalls, [1])
    }

    func testStartIsIdempotent() {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        var timerCreationCount = 0
        var schedulingCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
            makeBreakTimer: { config in
                timerCreationCount += 1
                return FakeBreakTimer(state: .init(phase: .work, remainingSeconds: config.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in
                schedulingCount += 1
                return {}
            }
        )

        coordinator.start()
        coordinator.start()

        XCTAssertEqual(fakeStatusItemController.installCallCount, 1)
        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(schedulingCount, 1)
    }

    func testTickTransitionsIntoBreakAndUpdatesOverlay() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 20),
                .init(phase: .rest, remainingSeconds: 19)
            ]
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([10, 11, 11, 12])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
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
            fakeOverlayManager.events,
            [.show(20), .update(19)]
        )
    }

    func testTickCompletesBreakAndHidesOverlay() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 1),
                .init(phase: .work, remainingSeconds: 300)
            ]
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([20, 21, 21, 22])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
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
            fakeOverlayManager.events,
            [.show(1), .hide]
        )
    }

    func testSkipFlowHidesOverlayAndStartsNextWorkInterval() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 20)
            ],
            skipState: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([30, 31, 31])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
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

        XCTAssertEqual(fakeTimer.skipBreakCallCount, 1)
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(20), .hide]
        )
    }

    func testSkipBreakResetsElapsedBaselineForNextWorkTick() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)],
            skipState: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([30, 31, 31, 34, 35.5])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
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
        scheduledTick?()

        XCTAssertEqual(fakeTimer.advanceCalls, [1, 1.5])
    }

    func testTickUsesElapsedAwakeTimeInsteadOfAssumingOneSecond() {
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([50, 52.5])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: currentUptime
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(fakeTimer.advanceCalls, [2.5])
    }

    func testLargestSupportedDurationAccumulatesSubsecondTicksUntilAWholeSecondCanBeConsumed() {
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: AppConfig.maximumSupportedDurationSeconds)
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([200, 200.5, 201])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { .default },
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

        XCTAssertEqual(fakeTimer.advanceCalls, [1])
    }

    func testDelayedWorkTickShowsFullBreakBeforeConsumingBreakTime() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 20),
                .init(phase: .rest, remainingSeconds: 19)
            ]
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([100, 105, 105, 106])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
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

        XCTAssertEqual(fakeTimer.advanceCalls, [1, 1])
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(20), .update(19)]
        )
    }

    func testSuccessfulBreakPresentationResetsElapsedBaselineAfterOverlayShowReturns() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 20),
                .init(phase: .rest, remainingSeconds: 19)
            ]
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([300, 305, 305.4, 306.4])

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
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

        XCTAssertEqual(fakeTimer.advanceCalls, [1, 1])
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(20), .update(19)]
        )
    }

    func testDeinitCancelsScheduledTicker() {
        let cancellationSpy = CancellationSpy()
        weak var weakCoordinator: AppCoordinator?

        do {
            let coordinator = AppCoordinator(
                statusItemController: FakeStatusItemController(),
                overlayManager: FakeBreakOverlayManager(),
                loadConfig: { .default },
                makeBreakTimer: { _ in FakeBreakTimer() },
                scheduleRepeatingTick: { _, _ in
                    cancellationSpy.cancel
                }
            )
            weakCoordinator = coordinator

            coordinator.start()
        }

        XCTAssertNil(weakCoordinator)
        XCTAssertEqual(cancellationSpy.cancelCallCount, 1)
    }
}
