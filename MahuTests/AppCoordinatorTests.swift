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
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
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
            },
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        coordinator.start()

        XCTAssertEqual(fakeStatusItemController.installCallCount, 1)
        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(schedulingCount, 1)
        XCTAssertEqual(fakeSleepWakeRegistrar.registrationCount, 1)
    }

    func testStartSeedsLaunchAtLoginDesiredStateFromStartupConfigBeforeSync() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: true
        )
        let fakeLaunchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: false)
        var syncedDesiredStates: [Bool] = []
        let fakeLaunchAtLoginController = FakeLaunchAtLoginController {
            syncedDesiredStates.append(fakeLaunchAtLoginStore.launchAtLoginEnabled)
        }

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            launchAtLoginSettingsStore: fakeLaunchAtLoginStore,
            makeLaunchAtLoginController: { _ in fakeLaunchAtLoginController },
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                FakeBreakTimer(state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()

        XCTAssertEqual(fakeLaunchAtLoginStore.updates, [true])
        XCTAssertEqual(syncedDesiredStates, [true])
        XCTAssertEqual(fakeLaunchAtLoginController.syncCallCount, 1)
    }

    func testStartSyncsLaunchAtLoginUsingConfigBackedDesiredState() {
        do {
            let startupConfig = AppConfig(
                workDurationSeconds: 300,
                breakDurationSeconds: 20,
                launchAtLoginEnabled: true
            )
            let fakeLaunchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: false)
            var syncedDesiredStates: [Bool] = []
            let fakeLaunchAtLoginController = FakeLaunchAtLoginController {
                syncedDesiredStates.append(fakeLaunchAtLoginStore.launchAtLoginEnabled)
            }
            fakeLaunchAtLoginController.syncResult = LaunchAtLoginSyncResult(action: .register, status: .enabled, warning: nil)

            let coordinator = AppCoordinator(
                statusItemController: FakeStatusItemController(),
                overlayManager: FakeBreakOverlayManager(),
                launchAtLoginSettingsStore: fakeLaunchAtLoginStore,
                makeLaunchAtLoginController: { _ in fakeLaunchAtLoginController },
                loadConfig: { startupConfig },
                makeBreakTimer: { _ in
                    FakeBreakTimer(state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds))
                },
                scheduleRepeatingTick: { _, _ in {} }
            )

            coordinator.start()

            XCTAssertEqual(syncedDesiredStates, [true])
            XCTAssertEqual(fakeLaunchAtLoginController.syncCallCount, 1)
        }

        do {
            let startupConfig = AppConfig(
                workDurationSeconds: 300,
                breakDurationSeconds: 20,
                launchAtLoginEnabled: false
            )
            let fakeLaunchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: true)
            var syncedDesiredStates: [Bool] = []
            let fakeLaunchAtLoginController = FakeLaunchAtLoginController {
                syncedDesiredStates.append(fakeLaunchAtLoginStore.launchAtLoginEnabled)
            }
            fakeLaunchAtLoginController.syncResult = LaunchAtLoginSyncResult(action: .unregister, status: .disabled, warning: nil)

            let coordinator = AppCoordinator(
                statusItemController: FakeStatusItemController(),
                overlayManager: FakeBreakOverlayManager(),
                launchAtLoginSettingsStore: fakeLaunchAtLoginStore,
                makeLaunchAtLoginController: { _ in fakeLaunchAtLoginController },
                loadConfig: { startupConfig },
                makeBreakTimer: { _ in
                    FakeBreakTimer(state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds))
                },
                scheduleRepeatingTick: { _, _ in {} }
            )

            coordinator.start()

            XCTAssertEqual(syncedDesiredStates, [false])
            XCTAssertEqual(fakeLaunchAtLoginController.syncCallCount, 1)
        }
    }

    func testLaunchAtLoginSyncWarningsDoNotPreventStatusItemInstallOrTimerStartup() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: true
        )
        let fakeStatusItemController = FakeStatusItemController()
        let fakeLaunchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: false)
        let fakeLaunchAtLoginController = FakeLaunchAtLoginController()
        fakeLaunchAtLoginController.syncResult = LaunchAtLoginSyncResult(
            action: .register,
            status: .disabled,
            warning: .registrationFailed
        )
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds - 1)]
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            launchAtLoginSettingsStore: fakeLaunchAtLoginStore,
            makeLaunchAtLoginController: { _ in fakeLaunchAtLoginController },
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101])
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(fakeLaunchAtLoginController.syncCallCount, 1)
        XCTAssertEqual(fakeStatusItemController.installCallCount, 1)
        XCTAssertEqual(fakeTimer.advanceCalls, [1])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
                .active(phase: .work, remainingSeconds: startupConfig.workDurationSeconds - 1)
            ]
        )
    }

    func testDidWakeWithoutRecordedWillSleepDoesNotResetTimerDestructively() {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return fakeTimer
            },
            scheduleRepeatingTick: { _, _ in
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 100]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(fakeSleepWakeRegistrar.didWakeCallCount, 1)
        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.count, 1)
        XCTAssertTrue(fakeOverlayManager.events.isEmpty)
    }

    func testDidWakeWithoutRecordedWillSleepRefreshesElapsedBaselineBeforeNextTick() {
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([10, 20, 21]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(fakeTimer.advanceCalls, [1])
    }

    func testLongSleepDuringActiveWorkResetsToFreshFullWorkInterval() {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 3)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 1_000),
            Date(timeIntervalSinceReferenceDate: 1_000 + longSleepResetThresholdSeconds + 1)
        ]
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: initialConfig),
            loadConfig: { initialConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return timerCreationCount == 1 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, _ in
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 200, 200]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(fakeStatusItemController.statusDisplayStates.first, .active(phase: .work, remainingSeconds: 3))
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates.last,
            .active(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)
        )
    }

    func testNextTickAfterLongSleepDoesNotImmediatelyTransitionToRest() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let expiringTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: initialConfig.breakDurationSeconds)]
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 2_000),
            Date(timeIntervalSinceReferenceDate: 2_000 + longSleepResetThresholdSeconds + 30)
        ]
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: initialConfig),
            loadConfig: { initialConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return timerCreationCount == 1 ? expiringTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([10, 20, 21, 22, 23, 24]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(resetTimer.advanceCalls, [1])
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(initialConfig.breakDurationSeconds, AppConfig.defaultBreakOverlayMessageText), .hide]
        )
    }

    func testShortSleepDuringActiveWorkPreservesRemainingWorkTime() {
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 120)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 3_000),
            Date(timeIntervalSinceReferenceDate: 3_000 + longSleepResetThresholdSeconds - 1)
        ]
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return initialTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([30, 30, 40, 41]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(initialTimer.advanceCalls, [1])
    }

    func testShortSleepDuringActiveRestPreservesBreakCountdownAndOverlayState() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let restTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 20),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 19)]
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 7_000),
            Date(timeIntervalSinceReferenceDate: 7_000 + longSleepResetThresholdSeconds - 1)
        ]
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return restTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([70, 70, 70, 80, 81]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(restTimer.advanceCalls, [1])
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(20, AppConfig.defaultBreakOverlayMessageText), .update(19)]
        )
    }

    func testLongSleepDuringActiveRestHidesOverlayAndStartsFreshWorkInterval() {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let restTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 7)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)
        )
        let sleepDates = [
            Date(timeIntervalSinceReferenceDate: 8_000),
            Date(timeIntervalSinceReferenceDate: 8_000 + longSleepResetThresholdSeconds + 5)
        ]
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
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
            currentUptime: makeCurrentUptimeProvider([90, 90, 90, 100]),
            currentSleepAwareTime: makeCurrentSleepAwareTimeProvider(sleepDates),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(restTimer.advanceCalls, [])
        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(7, AppConfig.defaultBreakOverlayMessageText), .hide]
        )
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .rest, remainingSeconds: 7),
                .active(phase: .work, remainingSeconds: initialConfig.workDurationSeconds)
            ]
        )
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
            [.show(20, AppConfig.defaultBreakOverlayMessageText), .update(19)]
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
            [.show(1, AppConfig.defaultBreakOverlayMessageText), .hide]
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
            [.show(20, AppConfig.defaultBreakOverlayMessageText), .hide]
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
            [.show(20, AppConfig.defaultBreakOverlayMessageText), .update(19)]
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
            [.show(20, AppConfig.defaultBreakOverlayMessageText), .update(19)]
        )
    }

    func testDeinitCancelsScheduledTickerAndSleepWakeObservation() {
        let cancellationSpy = CancellationSpy()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        weak var weakCoordinator: AppCoordinator?

        do {
            let coordinator = AppCoordinator(
                statusItemController: FakeStatusItemController(),
                overlayManager: FakeBreakOverlayManager(),
                loadConfig: { .default },
                makeBreakTimer: { _ in FakeBreakTimer() },
                scheduleRepeatingTick: { _, _ in
                    cancellationSpy.cancel
                },
                sleepWakeRegistrar: fakeSleepWakeRegistrar.register
            )
            weakCoordinator = coordinator

            coordinator.start()
        }

        XCTAssertNil(weakCoordinator)
        XCTAssertEqual(cancellationSpy.cancelCallCount, 1)
        XCTAssertEqual(fakeSleepWakeRegistrar.cancelCount, 1)
    }

    func testSleepWakeCallbacksDoNotFireAfterCoordinatorTeardown() {
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()

        do {
            let coordinator = AppCoordinator(
                statusItemController: FakeStatusItemController(),
                overlayManager: FakeBreakOverlayManager(),
                loadConfig: { .default },
                makeBreakTimer: { _ in FakeBreakTimer() },
                scheduleRepeatingTick: { _, _ in {} },
                sleepWakeRegistrar: fakeSleepWakeRegistrar.register
            )

            coordinator.start()
        }

        fakeSleepWakeRegistrar.fireAllWillSleep()
        fakeSleepWakeRegistrar.fireAllDidWake()

        XCTAssertEqual(fakeSleepWakeRegistrar.cancelCount, 1)
        XCTAssertEqual(fakeSleepWakeRegistrar.willSleepCallCount, 0)
        XCTAssertEqual(fakeSleepWakeRegistrar.didWakeCallCount, 0)
    }
}
