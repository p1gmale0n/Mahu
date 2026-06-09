import Foundation
import XCTest
@testable import Mahu

@MainActor
final class RuntimeSettingsStoreTests: XCTestCase {
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
        try super.tearDownWithError()
    }

    func testRuntimeSettingsStoreDefaultsToAppConfigDefault() {
        let store = RuntimeSettingsStore()

        XCTAssertEqual(store.currentSettings, .default)
    }

    func testRuntimeSettingsStorePublishesAcceptedUpdatesAndSupportsObserverCancellation() {
        let store = RuntimeSettingsStore()
        let firstUpdate = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 30,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Focus reset"
        )
        let secondUpdate = AppConfig(
            workDurationSeconds: 1_200,
            breakDurationSeconds: 45,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Second update"
        )
        var observerOneEvents: [AppConfig] = []
        var observerTwoEvents: [AppConfig] = []

        let cancelObserverOne = store.addObserver { observerOneEvents.append($0) }
        _ = store.addObserver { observerTwoEvents.append($0) }

        store.update(firstUpdate)
        store.update(firstUpdate)
        cancelObserverOne()
        store.update(secondUpdate)

        XCTAssertEqual(store.currentSettings, secondUpdate)
        XCTAssertEqual(observerOneEvents, [firstUpdate])
        XCTAssertEqual(observerTwoEvents, [firstUpdate, secondUpdate])
    }

    func testRuntimeSettingsStoreRejectsUnsupportedDurationUpdates() {
        let store = RuntimeSettingsStore()
        let unsupportedUpdates = [
            AppConfig(workDurationSeconds: 0, breakDurationSeconds: 20),
            AppConfig(workDurationSeconds: 0.5, breakDurationSeconds: 20),
            AppConfig(workDurationSeconds: .infinity, breakDurationSeconds: 20),
        ]
        var receivedSettings: [AppConfig] = []

        _ = store.addObserver { receivedSettings.append($0) }
        unsupportedUpdates.forEach(store.update)

        XCTAssertEqual(store.currentSettings, .default)
        XCTAssertTrue(receivedSettings.isEmpty)
    }

    func testRuntimeSettingsStoreRejectsUnsupportedIdleAwayThresholdUpdates() {
        let store = RuntimeSettingsStore()
        let unsupportedUpdates = [
            AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20, idleAwayResetThresholdSeconds: 0),
            AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20, idleAwayResetThresholdSeconds: -5),
            AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20, idleAwayResetThresholdSeconds: .infinity),
        ]
        var receivedSettings: [AppConfig] = []

        _ = store.addObserver { receivedSettings.append($0) }
        unsupportedUpdates.forEach(store.update)

        XCTAssertEqual(store.currentSettings, .default)
        XCTAssertTrue(receivedSettings.isEmpty)
    }

    func testRuntimeSettingsStoreUpdatesDoNotTouchFilesystem() throws {
        let store = RuntimeSettingsStore()
        let runtimeOnlyConfig = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 15,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Runtime only"
        )
        let configStore = ConfigStore(appSupportDirectory: temporaryDirectoryURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: configStore.configURL.path))

        store.update(runtimeOnlyConfig)

        XCTAssertEqual(store.currentSettings, runtimeOnlyConfig)
        XCTAssertFalse(FileManager.default.fileExists(atPath: configStore.configURL.path))
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: temporaryDirectoryURL.path),
            []
        )
    }
}
