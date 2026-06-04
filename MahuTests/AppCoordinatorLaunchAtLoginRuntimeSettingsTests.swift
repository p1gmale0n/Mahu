import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorLaunchAtLoginRuntimeSettingsTests: XCTestCase {
    func testRuntimeSettingsUpdateResyncsLaunchAtLoginWhenDesiredStateEnables() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: false
        )
        let runtimeEditedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeLaunchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: false)
        var syncedDesiredStates: [Bool] = []
        let fakeLaunchAtLoginController = FakeLaunchAtLoginController {
            syncedDesiredStates.append(fakeLaunchAtLoginStore.launchAtLoginEnabled)
        }

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            launchAtLoginSettingsStore: fakeLaunchAtLoginStore,
            runtimeSettingsStore: runtimeSettingsStore,
            makeLaunchAtLoginController: { _ in fakeLaunchAtLoginController },
            loadConfig: { startupConfig },
            makeBreakTimer: { config in
                FakeBreakTimer(state: .init(phase: .work, remainingSeconds: config.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        runtimeSettingsStore.update(runtimeEditedConfig)

        XCTAssertEqual(fakeLaunchAtLoginStore.updates, [true])
        XCTAssertEqual(syncedDesiredStates, [false, true])
        XCTAssertEqual(fakeLaunchAtLoginController.syncCallCount, 2)
    }

    func testRuntimeSettingsUpdateResyncsLaunchAtLoginWhenDesiredStateDisables() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: true
        )
        let runtimeEditedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeLaunchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: true)
        var syncedDesiredStates: [Bool] = []
        let fakeLaunchAtLoginController = FakeLaunchAtLoginController {
            syncedDesiredStates.append(fakeLaunchAtLoginStore.launchAtLoginEnabled)
        }

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            launchAtLoginSettingsStore: fakeLaunchAtLoginStore,
            runtimeSettingsStore: runtimeSettingsStore,
            makeLaunchAtLoginController: { _ in fakeLaunchAtLoginController },
            loadConfig: { startupConfig },
            makeBreakTimer: { config in
                FakeBreakTimer(state: .init(phase: .work, remainingSeconds: config.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        runtimeSettingsStore.update(runtimeEditedConfig)

        XCTAssertEqual(fakeLaunchAtLoginStore.updates, [false])
        XCTAssertEqual(syncedDesiredStates, [true, false])
        XCTAssertEqual(fakeLaunchAtLoginController.syncCallCount, 2)
    }

    func testRuntimeSettingsUpdateDoesNotResyncLaunchAtLoginWhenDesiredStateIsUnchanged() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: false
        )
        let runtimeEditedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 45,
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeLaunchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: false)
        var syncedDesiredStates: [Bool] = []
        let fakeLaunchAtLoginController = FakeLaunchAtLoginController {
            syncedDesiredStates.append(fakeLaunchAtLoginStore.launchAtLoginEnabled)
        }

        let coordinator = AppCoordinator(
            statusItemController: FakeStatusItemController(),
            overlayManager: FakeBreakOverlayManager(),
            launchAtLoginSettingsStore: fakeLaunchAtLoginStore,
            runtimeSettingsStore: runtimeSettingsStore,
            makeLaunchAtLoginController: { _ in fakeLaunchAtLoginController },
            loadConfig: { startupConfig },
            makeBreakTimer: { config in
                FakeBreakTimer(state: .init(phase: .work, remainingSeconds: config.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        runtimeSettingsStore.update(runtimeEditedConfig)

        XCTAssertTrue(fakeLaunchAtLoginStore.updates.isEmpty)
        XCTAssertEqual(syncedDesiredStates, [false])
        XCTAssertEqual(fakeLaunchAtLoginController.syncCallCount, 1)
    }

    func testRuntimeSettingsWarningDuringLaunchAtLoginResyncDoesNotInterruptOtherRuntimeUpdates() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: false,
            launchAtLoginEnabled: false
        )
        let runtimeEditedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true,
            launchAtLoginEnabled: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeLaunchAtLoginStore = FakeLaunchAtLoginSettingsStore(launchAtLoginEnabled: false)
        let fakeStatusItemController = FakeStatusItemController()
        var syncedDesiredStates: [Bool] = []
        let fakeLaunchAtLoginController = FakeLaunchAtLoginController {
            syncedDesiredStates.append(fakeLaunchAtLoginStore.launchAtLoginEnabled)
        }
        fakeLaunchAtLoginController.syncResult = LaunchAtLoginSyncResult(
            action: .register,
            status: .disabled,
            warning: .registrationFailed
        )

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            launchAtLoginSettingsStore: fakeLaunchAtLoginStore,
            runtimeSettingsStore: runtimeSettingsStore,
            makeLaunchAtLoginController: { _ in fakeLaunchAtLoginController },
            loadConfig: { startupConfig },
            makeBreakTimer: { config in
                FakeBreakTimer(state: .init(phase: .work, remainingSeconds: config.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        runtimeSettingsStore.update(runtimeEditedConfig)

        XCTAssertEqual(fakeLaunchAtLoginStore.updates, [true])
        XCTAssertEqual(syncedDesiredStates, [false, true])
        XCTAssertEqual(fakeLaunchAtLoginController.syncCallCount, 2)
        XCTAssertEqual(fakeStatusItemController.showsTimerStateUpdates, [false, true])
        XCTAssertEqual(
            fakeStatusItemController.statusDisplayStates.last,
            .active(phase: .work, remainingSeconds: runtimeEditedConfig.workDurationSeconds)
        )
    }
}
