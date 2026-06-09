import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorStatusItemPauseResumeTests: XCTestCase {
    func testPauseShowsPausedTextAndStopsWorkCountdownWhilePausedInTimerMode() throws {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([10, 11, 12])

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
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)

        pauseReminders()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Paused"])
        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
    }

    func testResumeResetsToFreshFullWorkIntervalAndUpdatesStatusDisplay() throws {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        let resumedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        var createdTimers = 0
        var scheduledTick: (() -> Void)?
        var uptime = 20.0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
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
        uptime = 25
        scheduledTick?()

        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        resumeReminders()
        uptime = 26
        scheduledTick?()

        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true, false])
        XCTAssertEqual(
            fakeStatusItemController.renderedTimerTexts,
            ["05:00", "Paused", "05:00"]
        )
        XCTAssertEqual(initialTimer.advanceCalls, [5])
        XCTAssertEqual(resumedTimer.advanceCalls, [1])
    }

    func testPauseDuringActiveBreakKeepsRestCountdownVisibleInTimerMode() throws {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 20),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 14)]
        )
        var scheduledTick: (() -> Void)?
        var uptime = 100.0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { config },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: { uptime }
        )

        coordinator.start()
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)

        pauseReminders()
        uptime = 106
        scheduledTick?()

        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true])
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["00:20", "00:14"])
        XCTAssertEqual(fakeTimer.advanceCalls, [6])
    }

    func testSessionInactiveWhilePausedKeepsPausedTextInsteadOfAway() throws {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: config),
            loadConfig: { config },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([10, 10]),
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)

        pauseReminders()
        fakeSessionActivityRegistrar.fireDidResignActive()

        XCTAssertEqual(fakeSessionActivityRegistrar.didResignActiveCallCount, 1)
        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true])
        XCTAssertFalse(fakeStatusItemController.statusDisplayStates.contains(.away))
        XCTAssertEqual(fakeStatusItemController.renderedTimerTexts, ["05:00", "Paused"])
        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
    }

    func testSessionInactiveDuringPausedRestUnlocksBackToPausedFreshWorkWithoutSoundOrElapsed() throws {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 10)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: config.workDurationSeconds)
        )
        var scheduledTick: (() -> Void)?
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: config),
            loadConfig: { config },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 100, 100, 110]),
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)

        pauseReminders()
        fakeSessionActivityRegistrar.fireDidResignActive()
        fakeSessionActivityRegistrar.fireDidBecomeActive()
        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(fakeSessionActivityRegistrar.didResignActiveCallCount, 1)
        XCTAssertEqual(fakeSessionActivityRegistrar.didBecomeActiveCallCount, 1)
        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true])
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(10, AppConfig.defaultBreakOverlayMessageText), .hide]
        )
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
        XCTAssertFalse(fakeStatusItemController.statusDisplayStates.contains(.away))
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .rest, remainingSeconds: 10),
                .active(phase: .rest, remainingSeconds: 10),
                .active(phase: .work, remainingSeconds: config.workDurationSeconds),
                .active(phase: .work, remainingSeconds: config.workDurationSeconds)
            ]
        )
        XCTAssertEqual(
            fakeStatusItemController.renderedTimerTexts,
            ["00:10", "Paused"]
        )
    }

    func testSessionInactiveWithIconOnlyStatusItemDoesNotRenderAwayText() {
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: false
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSessionActivityRegistrar = FakeSessionActivityObserverRegistrar()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: config),
            loadConfig: { config },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([10, 10]),
            userAwayActivityRegistrar: fakeSessionActivityRegistrar.register,
            userIdleTimeProvider: FailingUserIdleTimeProvider()
        )

        coordinator.start()
        fakeSessionActivityRegistrar.fireDidResignActive()

        XCTAssertEqual(fakeStatusItemController.showsTimerStateUpdates, [false])
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates, [.active(phase: .work, remainingSeconds: 300), .away])
        XCTAssertTrue(fakeStatusItemController.renderedTimerTexts.isEmpty)
        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
    }
}
