import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorBreakPresentationTests: XCTestCase {
    func testFailedBreakPresentationRetriesWithoutConsumingRestTime() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        fakeOverlayManager.showBreakResult = false
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)]
        )
        var scheduledTick: (() -> Void)?
        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([70, 71, 72])
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(fakeTimer.advanceCalls, [1])
        XCTAssertEqual(fakeOverlayManager.events, [.show(20), .show(20)])
    }

    func testLateBreakCompletionTickDoesNotConsumeNextWorkIntervalBeforeOverlayHides() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 1),
                .init(phase: .work, remainingSeconds: 300),
                .init(phase: .work, remainingSeconds: 299)
            ]
        )
        var scheduledTick: (() -> Void)?
        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([20, 21, 21, 25, 25, 26])
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(fakeTimer.advanceCalls, [1, 1, 1])
        XCTAssertEqual(fakeOverlayManager.events, [.show(1), .hide])
    }
}
