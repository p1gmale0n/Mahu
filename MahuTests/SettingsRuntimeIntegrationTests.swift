import XCTest
@testable import Mahu

@MainActor
final class SettingsRuntimeIntegrationTests: XCTestCase {
    func testSettingsViewModelWorkDurationUpdateRestartsActiveWorkThroughSharedRuntimeStore() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        let restartedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 600)
        )
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : restartedTimer
            },
            scheduleRepeatingTick: { _, _ in {} }
        )
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        coordinator.start()
        viewModel.updateWorkDurationMinutes(10)

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.workDurationSeconds, 600)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(
            statusItemController.statusDisplayStates,
            [
                .active(phase: .work, remainingSeconds: 300),
                .active(phase: .work, remainingSeconds: 600)
            ]
        )
    }

    func testSettingsViewModelShowMenuTimerUpdateUpdatesStatusItemThroughCoordinatorObservation() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = FakeStatusItemController()

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                FakeBreakTimer(state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} }
        )
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        coordinator.start()
        viewModel.updateShowMenuTimer(true)

        XCTAssertEqual(statusItemController.showsTimerStateUpdates, [false, true])
        XCTAssertEqual(statusItemController.renderedTimerTexts, ["05:00"])
    }

    func testSettingsViewModelIdleAwayUpdatesChangeRuntimeBehaviorWithoutConfigReload() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false,
            idleAwayResetThresholdSeconds: 300,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        let resetTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        let idleProvider = RecordingUserIdleTimeProvider([60])
        var createdTimers = 0
        var scheduledTick: (() -> Void)?
        var loadConfigCallCount = 0

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: {
                loadConfigCallCount += 1
                return startupConfig
            },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resetTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 101]),
            userIdleTimeProvider: idleProvider
        )
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        coordinator.start()
        viewModel.updateIdleAwayResetEnabled(true)
        viewModel.updateIdleAwayResetMinutes(1)
        scheduledTick?()

        XCTAssertEqual(loadConfigCallCount, 0)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.idleAwayResetThresholdSeconds, 60)
        XCTAssertEqual(idleProvider.queryCount, 1)
        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(statusItemController.statusDisplayStates.last, .away)
    }

    func testRuntimeLaunchAtLoginUpdateUsesCoordinatorSyncPathAndKeepsWarningNonFatal() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let launchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: false)
        let statusItemController = FakeStatusItemController()
        var syncedDesiredStates: [Bool] = []
        let launchAtLoginController = FakeLaunchAtLoginController {
            syncedDesiredStates.append(launchAtLoginStore.launchAtLoginEnabled)
        }
        launchAtLoginController.syncResult = LaunchAtLoginSyncResult(
            action: .register,
            status: .disabled,
            warning: .registrationFailed
        )

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            launchAtLoginSettingsStore: launchAtLoginStore,
            runtimeSettingsStore: runtimeSettingsStore,
            makeLaunchAtLoginController: { _ in launchAtLoginController },
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                FakeBreakTimer(state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        runtimeSettingsStore.update(startupConfig.updating(launchAtLoginEnabled: true))

        XCTAssertEqual(launchAtLoginStore.updates, [true])
        XCTAssertEqual(syncedDesiredStates, [false, true])
        XCTAssertEqual(launchAtLoginController.syncCallCount, 2)
        XCTAssertEqual(statusItemController.statusDisplayStates.last, .active(phase: .work, remainingSeconds: 300))
    }

    func testSettingsViewModelCommittedBreakOverlayMessageChangeAppliesToNextBreakOnly() throws {
        let startupConfig = AppConfig(
            workDurationSeconds: 1,
            breakDurationSeconds: 20,
            breakOverlayMessageText: "Initial message"
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let overlayManager = FakeBreakOverlayManager()
        let breakTimer = FakeBreakTimer(
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
            overlayManager: overlayManager,
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in breakTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 101, 102, 103, 104, 105])
        )
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        coordinator.start()
        scheduledTick?()

        viewModel.updateBreakOverlayMessageDraft("Next break message")
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, "Initial message")
        viewModel.commitBreakOverlayMessageDraft()
        let skipBreak = try XCTUnwrap(overlayManager.skipHandler)
        skipBreak()
        scheduledTick?()

        XCTAssertEqual(
            overlayManager.events,
            [
                .show(20, "Initial message"),
                .hide,
                .show(25, "Next break message")
            ]
        )
    }
}

@MainActor
private func makeViewModel(runtimeSettingsStore: RuntimeSettingsStoring) -> SettingsViewModel {
    SettingsViewModel(
        runtimeSettingsStore: runtimeSettingsStore,
        saveConfig: { _ in true }
    )
}
