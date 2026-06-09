import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorIdleAwayResetTests: XCTestCase {
    func testDisabledIdleAwayDoesNotQueryProviderSuppressElapsedOrBlockNearExpiredRestTransition() {
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)]
        )
        let fakeIdleProvider = RecordingUserIdleTimeProvider([longSleepResetThresholdSeconds])
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeStatusItemController = FakeStatusItemController()
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return fakeTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(fakeTimer.advanceCalls, [1])
        XCTAssertEqual(fakeIdleProvider.queryCount, 0)
        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText)])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 1),
                .active(phase: .rest, remainingSeconds: 20)
            ]
        )
    }

    func testLongIdleResetClearsElapsedCarryoverAndRefreshesTickBaseline() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true
        )
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600),
            statesToReturn: [.init(phase: .work, remainingSeconds: 599)]
        )
        let fakeIdleProvider = RecordingUserIdleTimeProvider([longSleepResetThresholdSeconds, 0])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 110, 111]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(resetTimer.advanceCalls, [1])
    }

    func testLongIdleDuringActiveRestResetsUsingCurrentRuntimeSettingsWithoutReloadingDiskConfig() {
        let initialSettings = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true
        )
        let updatedSettings = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 45,
            idleAwayResetEnabled: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: initialSettings)
        let fakeOverlayManager = FakeBreakOverlayManager()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 10)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedSettings.workDurationSeconds)
        )
        let fakeIdleProvider = RecordingUserIdleTimeProvider([longSleepResetThresholdSeconds])
        var scheduledTick: (() -> Void)?
        var createdConfigs: [AppConfig] = []
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: {
                XCTFail("loadConfig should not be used after runtime settings store injection")
                return .default
            },
            makeBreakTimer: { config in
                createdConfigs.append(config)
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedSettings)
        scheduledTick?()

        XCTAssertEqual(createdConfigs, [initialSettings, updatedSettings])
        XCTAssertEqual(fakeOverlayManager.events, [.show(10, AppConfig.defaultBreakOverlayMessageText), .hide])
    }

    func testRepeatedLongIdleTicksResetOnlyOncePerIdleEpisode() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true
        )
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        let fakeIdleProvider = RecordingUserIdleTimeProvider([
            longSleepResetThresholdSeconds,
            longSleepResetThresholdSeconds + 5,
            longSleepResetThresholdSeconds + 10
        ])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102, 103]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
    }

    func testIdleActivityBelowThresholdRearmsFutureLongIdleReset() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true
        )
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let firstResetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600),
            statesToReturn: [.init(phase: .work, remainingSeconds: 599)]
        )
        let secondResetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 900)
        )
        let fakeIdleProvider = RecordingUserIdleTimeProvider([
            longSleepResetThresholdSeconds,
            longSleepResetThresholdSeconds - 1,
            longSleepResetThresholdSeconds
        ])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { .default },
            makeBreakTimer: { config in
                defer { timerCreationCount += 1 }
                switch timerCreationCount {
                case 0:
                    return initialTimer
                case 1:
                    return firstResetTimer
                default:
                    XCTAssertEqual(config.workDurationSeconds, 600)
                    return secondResetTimer
                }
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102, 103]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 3)
        XCTAssertEqual(firstResetTimer.advanceCalls, [1])
        XCTAssertEqual(secondResetTimer.advanceCalls, [])
    }

    func testEnabledIdleAwayUsesRuntimeThresholdInsteadOfFixedLongSleepThreshold() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 120
        )
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: enabledSettings.workDurationSeconds)
        )
        let fakeIdleProvider = RecordingUserIdleTimeProvider([120])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(fakeIdleProvider.queryCount, 1)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resetTimer.advanceCalls, [])
    }

    func testDisablingIdleAwayClearsEpisodeStateBeforeFutureReEnable() {
        let initiallyEnabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true
        )
        let disabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false
        )
        let reenabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: initiallyEnabledSettings)
        let firstTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 300))
        let secondTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 600))
        let thirdTimer = FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 900))
        let fakeIdleProvider = RecordingUserIdleTimeProvider([
            longSleepResetThresholdSeconds,
            longSleepResetThresholdSeconds
        ])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { .default },
            makeBreakTimer: { config in
                defer { timerCreationCount += 1 }
                switch timerCreationCount {
                case 0:
                    return firstTimer
                case 1:
                    XCTAssertEqual(config.workDurationSeconds, 600)
                    return secondTimer
                default:
                    XCTAssertEqual(config.workDurationSeconds, 600)
                    return thirdTimer
                }
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()
        runtimeSettingsStore.update(disabledSettings)
        runtimeSettingsStore.update(reenabledSettings)
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 3)
        XCTAssertEqual(fakeIdleProvider.queryCount, 2)
        XCTAssertEqual(secondTimer.advanceCalls, [])
        XCTAssertEqual(thirdTimer.advanceCalls, [])
    }

    func testLaunchWhileAlreadyIdleDoesNotRepeatedlyReplaceTimer() {
        let enabledSettings = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true
        )
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        let fakeIdleProvider = RecordingUserIdleTimeProvider([longSleepResetThresholdSeconds])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: enabledSettings),
            loadConfig: { .default },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102]),
            userIdleTimeProvider: fakeIdleProvider
        )

        coordinator.start()
        scheduledTick?()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(resetTimer.advanceCalls, [])
    }
}
