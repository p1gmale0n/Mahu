import AppKit

enum AppRuntime {
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
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appCoordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppRuntime.isRunningTests() == false else {
            return
        }

        let appCoordinator = AppCoordinator()
        appCoordinator.start()
        self.appCoordinator = appCoordinator
    }
}
