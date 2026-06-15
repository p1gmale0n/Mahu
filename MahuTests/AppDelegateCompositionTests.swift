import AppKit
import XCTest
@testable import Mahu

@MainActor
final class AppDelegateCompositionTests: XCTestCase {
    func testAppDelegateUsesSharedRuntimeSettingsStoreForCoordinatorAndSettingsViewModel() {
        let startupConfig = AppConfig(
            workDurationSeconds: 1_800,
            breakDurationSeconds: 45,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 600,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Focus reset",
            launchAtLoginEnabled: true
        )
        let appDelegate = AppDelegate()
        let fakeStatusItemController = FakeStatusItemController()
        var capturedCoordinatorRuntimeStore: RuntimeSettingsStoring?
        var capturedSettingsViewModelRuntimeStore: RuntimeSettingsStoring?

        appDelegate.environmentProvider = { [:] }
        appDelegate.makeConfigStore = {
            Self.makeConfigStore(with: startupConfig)
        }
        appDelegate.makeStatusItemController = {
            fakeStatusItemController
        }
        appDelegate.makeSettingsViewModel = { runtimeSettingsStore, saveConfig in
            capturedSettingsViewModelRuntimeStore = runtimeSettingsStore
            return SettingsViewModel(runtimeSettingsStore: runtimeSettingsStore, saveConfig: saveConfig)
        }
        appDelegate.coordinatorStarter = { startsUserAway, _, _, runtimeSettingsStore in
            XCTAssertFalse(startsUserAway)
            capturedCoordinatorRuntimeStore = runtimeSettingsStore
            return NSObject()
        }

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertNotNil(fakeStatusItemController.showSettingsHandler)
        XCTAssertEqual(capturedCoordinatorRuntimeStore?.currentSettings, startupConfig)
        XCTAssertTrue(capturedCoordinatorRuntimeStore === capturedSettingsViewModelRuntimeStore)
    }

    func testAppDelegateSettingsHandlerReusesRetainedSettingsWindowController() {
        let appDelegate = AppDelegate()
        let fakeStatusItemController = FakeStatusItemController()
        var windowFactoryCallCount = 0
        var appActivationCallCount = 0

        appDelegate.environmentProvider = { [:] }
        appDelegate.makeConfigStore = {
            Self.makeConfigStore(with: .default)
        }
        appDelegate.makeStatusItemController = {
            fakeStatusItemController
        }
        appDelegate.makeSettingsWindowController = { _ in
            SettingsWindowController(
                makeContentViewController: { NSViewController() },
                windowFactory: { _ in
                    windowFactoryCallCount += 1
                    return NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
                        styleMask: [.titled, .closable],
                        backing: .buffered,
                        defer: false
                    )
                },
                appActivator: {
                    appActivationCallCount += 1
                }
            )
        }
        appDelegate.coordinatorStarter = { _, _, _, _ in
            NSObject()
        }

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        fakeStatusItemController.showSettingsHandler?()
        fakeStatusItemController.showSettingsHandler?()

        XCTAssertEqual(windowFactoryCallCount, 1)
        XCTAssertEqual(appActivationCallCount, 2)
    }

    private static func makeConfigStore(with config: AppConfig) -> ConfigStore {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appSupportDirectory = rootURL.appendingPathComponent("Application Support", isDirectory: true)
        let mahuDirectory = appSupportDirectory.appendingPathComponent("Mahu", isDirectory: true)

        try? FileManager.default.createDirectory(at: mahuDirectory, withIntermediateDirectories: true)
        let data = try? JSONEncoder().encode(config)
        FileManager.default.createFile(
            atPath: mahuDirectory.appendingPathComponent("config.json").path,
            contents: data
        )

        return ConfigStore(appSupportDirectory: appSupportDirectory)
    }
}
