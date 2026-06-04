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
}
