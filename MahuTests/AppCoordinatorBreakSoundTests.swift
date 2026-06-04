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

        XCTAssertEqual(fakeOverlayManager.events, [.show(1, AppConfig.defaultBreakOverlayMessageText), .hide])
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

        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText), .hide])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testSkipAtCompletionBoundaryDoesNotPlaySoundWhenLiveOverlayManagerHandlesSkip() throws {
        let display = DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), id: "built-in")
        let overlayManager = BreakOverlayManager(
            screenProvider: { [display] },
            windowBuilder: FakeOverlayWindowBuilder(),
            appActivator: {}
        )
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 1),
                .init(phase: .work, remainingSeconds: 300)
            ],
            skipState: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: overlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 101, 102])
        )

        coordinator.start()
        scheduledTick?()
        try XCTUnwrap(overlayManager.viewModel).skip()

        XCTAssertEqual(fakeTimer.advanceCalls, [1])
        XCTAssertEqual(fakeTimer.skipBreakCallCount, 1)
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
        XCTAssertFalse(overlayManager.hasVisibleOverlayWindows)
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

        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText)])
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

        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText), .show(20, AppConfig.defaultBreakOverlayMessageText)])
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

        XCTAssertEqual(fakeOverlayManager.events, [.show(1, AppConfig.defaultBreakOverlayMessageText), .hide])
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

        XCTAssertEqual(fakeOverlayManager.events, [.show(2, AppConfig.defaultBreakOverlayMessageText), .update(1)])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testLongSleepDuringActiveRestDoesNotPlayBreakCompletionSound() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let restTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 4)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 9_000),
            Date(timeIntervalSinceReferenceDate: 9_000 + longSleepResetThresholdSeconds + 20)
        ]
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: initialConfig),
            loadConfig: { initialConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return timerCreationCount == 1 ? restTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([110, 120, 121]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(
            fakeOverlayManager.events,
            [
                .show(4, AppConfig.defaultBreakOverlayMessageText),
                .update(4),
                .hide
            ]
        )
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testSleepEntryRestCompletionDoesNotPlayBreakCompletionSoundBeforeLongSleepReset() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSoundPlayer = FakeBreakCompletionSoundPlayer()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let restTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 4),
            statesToReturn: [.init(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)]
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 9_500),
            Date(timeIntervalSinceReferenceDate: 9_500 + longSleepResetThresholdSeconds + 20)
        ]
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            breakCompletionSoundPlayer: fakeSoundPlayer,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: initialConfig),
            loadConfig: { initialConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return timerCreationCount == 1 ? restTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([110, 110, 120, 121, 122]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(restTimer.advanceCalls, [4, 6])
        XCTAssertEqual(fakeOverlayManager.events, [.show(4, AppConfig.defaultBreakOverlayMessageText), .hide])
        XCTAssertEqual(fakeSoundPlayer.playCallCount, 0)
    }

    func testLongSleepDuringActiveRestPreservesOverlayTeardownInvariantsWithoutNaturalCompletionPaths() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let restTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 9),
            skipState: .init(phase: .work, remainingSeconds: 123)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 10_000),
            Date(timeIntervalSinceReferenceDate: 10_000 + longSleepResetThresholdSeconds + 12)
        ]
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: initialConfig),
            loadConfig: { initialConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return timerCreationCount == 1 ? restTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([130, 140, 141]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        XCTAssertNotNil(fakeOverlayManager.skipHandler)

        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(
            fakeOverlayManager.events,
            [
                .show(9, AppConfig.defaultBreakOverlayMessageText),
                .update(9),
                .hide
            ]
        )
        XCTAssertNil(fakeOverlayManager.skipHandler)
        XCTAssertEqual(restTimer.advanceCalls, [1])
        XCTAssertEqual(restTimer.skipBreakCallCount, 0)
    }
}
