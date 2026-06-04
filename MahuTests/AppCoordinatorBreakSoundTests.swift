import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorBreakSoundTests: XCTestCase {
    func testNaturalBreakCompletionPlaysSoundExactlyOnce() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 1),
                .init(phase: .work, remainingSeconds: 300)
            ]
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([10, 11, 11, 12])
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(fakeOverlayManager.events, [.show(1), .hide])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 1)
    }

    func testSkipHidesBreakWithoutPlayingSound() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)],
            skipState: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([20, 21, 21])
        )

        coordinator.start()
        scheduledTick?()
        fakeOverlayManager.skipHandler?()

        XCTAssertEqual(fakeOverlayManager.events, [.show(20), .hide])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testWorkToBreakTransitionDoesNotPlaySound() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)]
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([30, 31])
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(fakeOverlayManager.events, [.show(20)])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testFailedBreakPresentationRetryDoesNotPlaySound() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        fakeOverlayManager.showBreakResult = false
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)]
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([40, 41, 42])
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(fakeOverlayManager.events, [.show(20), .show(20)])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testPauseAndResumeReminderTogglesDoNotPlaySound() throws {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            breakCompletionSoundPlayer: fakeSoundPlayer,
            loadConfig: { .default },
            makeBreakTimer: { _ in FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 300)) },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()

        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        resumeReminders()

        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testNaturalBreakCompletionStillPlaysSoundWhenOverlayHidesAtTheCompletionBoundary() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let breakTimer = BreakTimer(workDurationSeconds: 1, breakDurationSeconds: 1)
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            loadConfig: { .default },
            makeBreakTimer: { _ in breakTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 101, 102])
        )

        coordinator.start()
        scheduledTick?()
        fakeOverlayManager.hasVisibleOverlayWindows = false

        XCTAssertEqual(fakeOverlayManager.events, [.show(1), .hide])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 1)
    }

    func testHiddenBreakDoesNotPlaySoundBeforeCompletion() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let breakTimer = BreakTimer(workDurationSeconds: 1, breakDurationSeconds: 2)
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            loadConfig: { .default },
            makeBreakTimer: { _ in breakTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([200, 201, 201, 202])
        )

        coordinator.start()
        scheduledTick?()
        fakeOverlayManager.hasVisibleOverlayWindows = false

        XCTAssertEqual(fakeOverlayManager.events, [.show(2), .update(1)])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }
}
