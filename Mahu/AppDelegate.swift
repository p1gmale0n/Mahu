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
    var environmentProvider: () -> [String: String] = { ProcessInfo.processInfo.environment }
    var sessionActivityRegistrar: SessionActivityObservationRegistrar = LiveSessionActivityObservationRegistrar.make
    var coordinatorStarter: @MainActor (_ startsSessionInactive: Bool) -> AnyObject = { startsSessionInactive in
        let appCoordinator = AppCoordinator()
        appCoordinator.start(initialSessionIsActive: startsSessionInactive == false)
        return appCoordinator
    }
    private var coordinatorLifetime: AnyObject?
    private var cancelInitialSessionActivityObservation: SessionActivityObservationCancellation?
    private var startsSessionInactive = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard AppRuntime.shouldStartProductionCoordinator(environment: environmentProvider()) else {
            return
        }

        guard cancelInitialSessionActivityObservation == nil else {
            return
        }

        cancelInitialSessionActivityObservation = sessionActivityRegistrar(
            { [weak self] in
                self?.startsSessionInactive = true
            },
            { [weak self] in
                self?.startsSessionInactive = false
            }
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppRuntime.shouldStartProductionCoordinator(environment: environmentProvider()) else {
            return
        }

        coordinatorLifetime = coordinatorStarter(startsSessionInactive)
        cancelInitialSessionActivityObservation?()
        cancelInitialSessionActivityObservation = nil
    }
}
