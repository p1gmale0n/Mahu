import AppKit

enum AppRuntime {
    static let disableCoordinatorStartupEnvironmentKey = "MAHU_DISABLE_APP_COORDINATOR_STARTUP"

    static func isRunningTests(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        let testMarkers = [
            "XCTestBundlePath",
            "XCTestConfigurationFilePath",
            "XCTestSessionIdentifier",
        ]

        return testMarkers.contains { marker in
            guard let value = environment[marker] else {
                return false
            }

            return value.isEmpty == false
        }
    }

    static func shouldStartProductionCoordinator(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment[disableCoordinatorStartupEnvironmentKey] == "1" {
            return false
        }

        return isRunningTests(environment: environment) == false
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    typealias CoordinatorStarter = @MainActor (
        _ startsUserAway: Bool,
        _ userAwayActivityRegistrar: @escaping UserAwayActivityObservationRegistrar,
        _ statusItemController: StatusItemControlling,
        _ runtimeSettingsStore: RuntimeSettingsStoring
    ) -> AnyObject

    var environmentProvider: () -> [String: String] = { ProcessInfo.processInfo.environment }
    var screenLockStateProvider: ScreenLockStateProviding = ScreenLockStateProvider()
    var userAwayActivityRegistrar: UserAwayActivityObservationRegistrar?
    var makeConfigStore: () -> ConfigStore = { ConfigStore() }
    var makeRuntimeSettingsStore: (AppConfig) -> RuntimeSettingsStoring = { RuntimeSettingsStore(initialSettings: $0) }
    var makeSettingsViewModel: (RuntimeSettingsStoring, @escaping SettingsViewModel.ConfigSaver) -> SettingsViewModel = {
        SettingsViewModel(runtimeSettingsStore: $0, saveConfig: $1)
    }
    var makeSettingsWindowController: (SettingsViewModel) -> SettingsWindowController = { SettingsWindowController(viewModel: $0) }
    var makeStatusItemController: () -> StatusItemControlling = { StatusItemController() }
    var coordinatorStarter: CoordinatorStarter = { startsUserAway, userAwayActivityRegistrar, statusItemController, runtimeSettingsStore in
        let appCoordinator = AppCoordinator(
            statusItemController: statusItemController,
            runtimeSettingsStore: runtimeSettingsStore,
            userAwayActivityRegistrar: userAwayActivityRegistrar
        )
        appCoordinator.start(initialUserIsActive: startsUserAway == false)
        return appCoordinator
    }
    private var coordinatorLifetime: AnyObject?
    private var settingsWindowController: SettingsWindowController?
    private var cancelInitialUserAwayObservation: UserAwayActivityObservationCancellation?
    private let startupUserAwayAggregationState = UserAwaySourceAggregationState()
    private var startsUserAway = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard AppRuntime.shouldStartProductionCoordinator(environment: environmentProvider()) else {
            return
        }

        guard cancelInitialUserAwayObservation == nil else {
            return
        }

        let userAwayActivityRegistrar = makeSharedUserAwayActivityRegistrar()
        cancelInitialUserAwayObservation = userAwayActivityRegistrar(
            { [weak self] in
                self?.startsUserAway = true
            },
            { [weak self] in
                self?.startsUserAway = false
            }
        )

        let startupScreenLockState = screenLockStateProvider.currentState()
        if startupScreenLockState.isScreenLocked {
            startupUserAwayAggregationState.seedScreenLockedIfNeeded()
        }
        if startupScreenLockState.isOffConsole {
            startupUserAwayAggregationState.seedSessionAwayIfNeeded()
        }
        startsUserAway = startsUserAway || startupScreenLockState.isUserAway
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppRuntime.shouldStartProductionCoordinator(environment: environmentProvider()) else {
            return
        }

        let configStore = makeConfigStore()
        let startupConfig = configStore.load()
        let runtimeSettingsStore = makeRuntimeSettingsStore(startupConfig)
        let settingsViewModel = makeSettingsViewModel(runtimeSettingsStore, configStore.save(_:))
        let settingsWindowController = makeSettingsWindowController(settingsViewModel)
        let statusItemController = makeStatusItemController()

        self.settingsWindowController = settingsWindowController
        statusItemController.configureSettingsAction { [weak self] in
            self?.settingsWindowController?.showSettingsWindow()
        }

        coordinatorLifetime = coordinatorStarter(
            startsUserAway,
            makeSharedUserAwayActivityRegistrar(),
            statusItemController,
            runtimeSettingsStore
        )
        cancelInitialUserAwayObservation?()
        cancelInitialUserAwayObservation = nil
    }

    private func makeSharedUserAwayActivityRegistrar() -> UserAwayActivityObservationRegistrar {
        if let userAwayActivityRegistrar {
            return userAwayActivityRegistrar
        }

        let aggregationState = startupUserAwayAggregationState
        return { didBecomeAway, didBecomeActive in
            LiveUserAwayActivityObservationRegistrar.make(
                didBecomeAway: didBecomeAway,
                didBecomeActive: didBecomeActive,
                sessionActivityRegistrar: LiveSessionActivityObservationRegistrar.make,
                screenLockRegistrar: LiveScreenLockObservationRegistrar.make,
                aggregationState: aggregationState
            )
        }
    }
}
