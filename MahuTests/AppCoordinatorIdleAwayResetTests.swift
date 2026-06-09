import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorIdleAwayResetTests: XCTestCase {
    func testShortIdleDuringActiveWorkConsumesOrdinaryElapsedTimeWithoutReset() {
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300),
            statesToReturn: [.init(phase: .work, remainingSeconds: 299)]
        )
        let fakeIdleProvider = FakeUserIdleTimeProvider([longSleepResetThresholdSeconds - 1])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
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
    }

    func testLongIdleResetClearsElapsedCarryoverAndRefreshesTickBaseline() {
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600),
            statesToReturn: [.init(phase: .work, remainingSeconds: 599)]
        )
        let fakeIdleProvider = FakeUserIdleTimeProvider([longSleepResetThresholdSeconds, 0])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(
                currentSettings: AppConfig(workDurationSeconds: 600, breakDurationSeconds: 20)
            ),
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
        let initialSettings = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let updatedSettings = AppConfig(workDurationSeconds: 900, breakDurationSeconds: 45)
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: initialSettings)
        let fakeOverlayManager = FakeBreakOverlayManager()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 10)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedSettings.workDurationSeconds)
        )
        let fakeIdleProvider = FakeUserIdleTimeProvider([longSleepResetThresholdSeconds])
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
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        let fakeIdleProvider = FakeUserIdleTimeProvider([
            longSleepResetThresholdSeconds,
            longSleepResetThresholdSeconds + 5,
            longSleepResetThresholdSeconds + 10
        ])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(
                currentSettings: AppConfig(workDurationSeconds: 600, breakDurationSeconds: 20)
            ),
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
        let fakeIdleProvider = FakeUserIdleTimeProvider([
            longSleepResetThresholdSeconds,
            longSleepResetThresholdSeconds - 1,
            longSleepResetThresholdSeconds
        ])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(
                currentSettings: AppConfig(workDurationSeconds: 600, breakDurationSeconds: 20)
            ),
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

    func testLaunchWhileAlreadyIdleDoesNotRepeatedlyReplaceTimer() {
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        let fakeIdleProvider = FakeUserIdleTimeProvider([longSleepResetThresholdSeconds])
        var scheduledTick: (() -> Void)?
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: FakeRuntimeSettingsStore(
                currentSettings: AppConfig(workDurationSeconds: 600, breakDurationSeconds: 20)
            ),
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

private final class FakeUserIdleTimeProvider: UserIdleTimeProviding {
    private var idleDurationSeconds: [TimeInterval]
    private let fallbackIdleDurationSeconds: TimeInterval

    init(_ idleDurationSeconds: [TimeInterval]) {
        self.idleDurationSeconds = idleDurationSeconds
        fallbackIdleDurationSeconds = idleDurationSeconds.last ?? 0
    }

    func currentIdleDurationSeconds() -> TimeInterval {
        guard idleDurationSeconds.isEmpty == false else {
            return fallbackIdleDurationSeconds
        }

        return idleDurationSeconds.removeFirst()
    }
}
