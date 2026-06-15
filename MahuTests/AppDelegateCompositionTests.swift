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
        var capturedCanPersistConfig: SettingsViewModel.ConfigPersistenceValidator?
        appDelegate.makeSettingsViewModel = { runtimeSettingsStore, saveConfig, canPersistConfig in
            capturedSettingsViewModelRuntimeStore = runtimeSettingsStore
            capturedCanPersistConfig = canPersistConfig
            return SettingsViewModel(
                runtimeSettingsStore: runtimeSettingsStore,
                saveConfig: saveConfig,
                canPersistConfig: canPersistConfig
            )
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
        XCTAssertTrue(capturedCanPersistConfig?(startupConfig) ?? false)
        XCTAssertFalse(
            capturedCanPersistConfig?(
                startupConfig.updating(breakOverlayMessageText: String(repeating: "x", count: 70_000))
            ) ?? true
        )
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

    func testAppDelegateWiresSettingsViewModelToRealConfigStorePersistence() throws {
        let startupConfig = AppConfig.default
        let appDelegate = AppDelegate()
        let configStore = Self.makeConfigStore(with: startupConfig)
        var capturedSettingsViewModel: SettingsViewModel?

        appDelegate.environmentProvider = { [:] }
        appDelegate.makeConfigStore = {
            configStore
        }
        appDelegate.makeStatusItemController = {
            FakeStatusItemController()
        }
        appDelegate.makeSettingsViewModel = { runtimeSettingsStore, saveConfig, canPersistConfig in
            let viewModel = SettingsViewModel(
                runtimeSettingsStore: runtimeSettingsStore,
                saveConfig: saveConfig,
                canPersistConfig: canPersistConfig
            )
            capturedSettingsViewModel = viewModel
            return viewModel
        }
        appDelegate.coordinatorStarter = { _, _, _, _ in
            NSObject()
        }

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        let viewModel = try XCTUnwrap(capturedSettingsViewModel)
        viewModel.updateShowMenuTimer(true)

        XCTAssertTrue(configStore.load().showStatusItemTimerState)
    }

    func testApplicationShouldTerminateCancelsQuitWhenVisibleSettingsDraftSaveFails() throws {
        let appDelegate = AppDelegate()
        let fakeStatusItemController = FakeStatusItemController()
        var capturedSettingsViewModel: SettingsViewModel?

        appDelegate.environmentProvider = { [:] }
        appDelegate.makeConfigStore = {
            Self.makeConfigStore(with: .default)
        }
        appDelegate.makeStatusItemController = {
            fakeStatusItemController
        }
        appDelegate.makeSettingsViewModel = { runtimeSettingsStore, _, canPersistConfig in
            let viewModel = SettingsViewModel(
                runtimeSettingsStore: runtimeSettingsStore,
                saveConfig: { _ in false },
                canPersistConfig: canPersistConfig
            )
            capturedSettingsViewModel = viewModel
            return viewModel
        }
        appDelegate.coordinatorStarter = { _, _, _, _ in
            NSObject()
        }

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        fakeStatusItemController.showSettingsHandler?()
        let viewModel = try XCTUnwrap(capturedSettingsViewModel)
        viewModel.updateBreakOverlayMessageDraft("Quit-triggered draft")

        let terminateReply = appDelegate.applicationShouldTerminate(NSApp)

        XCTAssertEqual(terminateReply, .terminateCancel)
        XCTAssertEqual(viewModel.breakOverlayMessageText, "Quit-triggered draft")
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "Quit-triggered draft")
        XCTAssertNotNil(viewModel.saveFailureMessage)
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
