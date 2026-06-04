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
        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText), .show(20, AppConfig.defaultBreakOverlayMessageText)])
    }

    func testDormantBreakSessionThatBecomesVisibleLaterHidesWhenBreakEnds() throws {
        let fakeOverlayManager = FakeBreakOverlayManager()
        fakeOverlayManager.showBreakResult = false
        fakeOverlayManager.preservesActiveBreakSessionOnFailedShow = true
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)],
            skipState: .init(phase: .work, remainingSeconds: 300)
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
            currentUptime: makeCurrentUptimeProvider([80, 81, 82])
        )

        coordinator.start()
        scheduledTick?()
        fakeOverlayManager.hasVisibleOverlayWindows = true
        let skipBreak = try XCTUnwrap(fakeOverlayManager.skipHandler)
        skipBreak()

        XCTAssertEqual(
            fakeOverlayManager.events,
            [.show(20, AppConfig.defaultBreakOverlayMessageText), .hide]
        )
        XCTAssertFalse(fakeOverlayManager.hasActiveBreakSession)
        XCTAssertFalse(fakeOverlayManager.hasVisibleOverlayWindows)
    }

    func testLateBreakCompletionTickCarriesOverflowIntoNextWorkIntervalAfterOverlayHides() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeStatusItemController = FakeStatusItemController()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 1),
                .init(phase: .work, remainingSeconds: 300),
                .init(phase: .work, remainingSeconds: 297)
            ]
        )
        var scheduledTick: (() -> Void)?
        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
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

        XCTAssertEqual(fakeTimer.advanceCalls, [1, 1, 3])
        XCTAssertEqual(fakeOverlayManager.events, [.show(1, AppConfig.defaultBreakOverlayMessageText), .hide])
        XCTAssertEqual(
            Array(fakeStatusItemController.statusDisplayStates.suffix(2)),
            [
                .active(phase: .work, remainingSeconds: 300),
                .active(phase: .work, remainingSeconds: 297)
            ]
        )
    }

    func testHiddenActiveBreakPausesCountdownUntilOverlayBecomesVisibleAgain() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 20),
                .init(phase: .rest, remainingSeconds: 19)
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
            currentUptime: makeCurrentUptimeProvider([100, 101, 102, 103, 104])
        )

        coordinator.start()
        scheduledTick?()
        fakeOverlayManager.hasVisibleOverlayWindows = false
        scheduledTick?()
        fakeOverlayManager.hasVisibleOverlayWindows = true
        scheduledTick?()

        XCTAssertEqual(fakeTimer.advanceCalls, [1, 1])
        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText), .update(19)])
    }

    func testBreakOnlyConsumesVisibleRestTimeWhenDisplaysDisappearBetweenTicks() {
        let fakeOverlayManager = FakeBreakOverlayManager()
        let breakTimer = BreakTimer(workDurationSeconds: 1, breakDurationSeconds: 20)
        var scheduledTick: (() -> Void)?
        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
            makeBreakTimer: { _ in breakTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 101, 101.4, 102.4, 103.4])
        )

        coordinator.start()
        scheduledTick?()
        fakeOverlayManager.hasVisibleOverlayWindows = false
        fakeOverlayManager.hasVisibleOverlayWindows = true
        scheduledTick?()

        guard case .show(let initialBreakSeconds, let initialMessageText)? = fakeOverlayManager.events.first else {
            return XCTFail("Expected the break overlay to be shown once before visibility transitions.")
        }

        let updateEvents = fakeOverlayManager.events.compactMap { event -> TimeInterval? in
            guard case .update(let remainingSeconds) = event else {
                return nil
            }

            return remainingSeconds
        }

        XCTAssertEqual(initialBreakSeconds, 20, accuracy: 0.0001)
        XCTAssertEqual(initialMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(updateEvents.count, 2)
        XCTAssertEqual(updateEvents[0], 19.6, accuracy: 0.0001)
        XCTAssertEqual(updateEvents[1], 18.6, accuracy: 0.0001)
    }

    func testCustomBreakOverlayMessageFromLoadedConfigReachesShowBreak() {
        let customMessage = "休憩しましょう — отдохни 🌿"
        let config = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            breakOverlayMessageText: customMessage
        )
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)]
        )
        var scheduledTick: (() -> Void)?
        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { config },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([300, 301])
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertEqual(fakeOverlayManager.events, [.show(20, customMessage)])
    }

    func testMissingBreakOverlayMessageConfigFieldStillSendsDefaultMessage() throws {
        let legacyConfigData = Data(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 20,
              "showStatusItemTimerState": true
            }
            """.utf8
        )
        let legacyConfig = try JSONDecoder().decode(AppConfig.self, from: legacyConfigData)
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 20)]
        )
        var scheduledTick: (() -> Void)?
        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            loadConfig: { legacyConfig },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([400, 401])
        )

        coordinator.start()
        scheduledTick?()

        XCTAssertTrue(legacyConfig.showStatusItemTimerState)
        XCTAssertEqual(legacyConfig.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(fakeOverlayManager.events, [.show(20, AppConfig.defaultBreakOverlayMessageText)])
    }

    func testRuntimeBreakOverlayMessageChangeAppliesToNextBreakOnly() throws {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            breakOverlayMessageText: "Initial message"
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            breakOverlayMessageText: "Next break message"
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1),
            statesToReturn: [
                .init(phase: .rest, remainingSeconds: 20),
                .init(phase: .rest, remainingSeconds: 25)
            ],
            skipState: .init(phase: .work, remainingSeconds: 1)
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: fakeOverlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102, 103, 104, 105])
        )

        coordinator.start()
        scheduledTick?()

        runtimeSettingsStore.update(updatedConfig)
        let skipBreak = try XCTUnwrap(fakeOverlayManager.skipHandler)
        skipBreak()
        scheduledTick?()

        XCTAssertEqual(
            fakeOverlayManager.events,
            [
                .show(20, "Initial message"),
                .hide,
                .show(25, "Next break message")
            ]
        )
    }
}
