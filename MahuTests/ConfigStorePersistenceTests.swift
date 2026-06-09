import Foundation
import XCTest
@testable import Mahu

final class ConfigStorePersistenceTests: XCTestCase {
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

    func testSaveWritesConfigThatLoadCanReadBack() {
        let store = makeStore()
        let savedConfig = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Saved config",
            launchAtLoginEnabled: true
        )

        XCTAssertTrue(store.save(savedConfig))
        XCTAssertEqual(store.load(), savedConfig)
    }

    func testSaveRefusesConfigSymlinkWithoutTouchingItsTarget() throws {
        let store = makeStore()
        let sharedConfigURL = temporaryDirectoryURL.appendingPathComponent("shared-config.json", isDirectory: false)
        let initialConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let savedConfig = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Saved via symlink",
            launchAtLoginEnabled: true
        )

        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(initialConfig).write(to: sharedConfigURL, options: .atomic)
        try FileManager.default.createSymbolicLink(at: store.configURL, withDestinationURL: sharedConfigURL)

        XCTAssertFalse(store.save(savedConfig))

        let configResourceType = try XCTUnwrap(
            store.configURL.resourceValues(forKeys: [.fileResourceTypeKey]).fileResourceType
        )
        XCTAssertEqual(configResourceType, .symbolicLink)
        let persistedConfig = try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: sharedConfigURL))
        XCTAssertEqual(persistedConfig, initialConfig)
        XCTAssertEqual(store.load(), initialConfig)
    }

    func testSaveRefusesSymlinkedMahuConfigDirectoryWithoutWritingThroughIt() throws {
        let store = makeStore()
        let sharedDirectoryURL = temporaryDirectoryURL.appendingPathComponent("shared-config-directory", isDirectory: true)
        let savedConfig = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Saved via symlinked directory",
            launchAtLoginEnabled: true
        )

        try FileManager.default.createDirectory(at: sharedDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent().deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: store.configURL.deletingLastPathComponent(),
            withDestinationURL: sharedDirectoryURL
        )

        XCTAssertFalse(store.save(savedConfig))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sharedDirectoryURL.appendingPathComponent("config.json").path))
    }

    func testSaveCreatesConfigParentDirectoryWhenNeeded() throws {
        let rootDirectoryURL = temporaryDirectoryURL.appendingPathComponent("nested/root", isDirectory: true)
        let store = ConfigStore(appSupportDirectory: rootDirectoryURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.deletingLastPathComponent().path))

        XCTAssertTrue(store.save(.default))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.configURL.deletingLastPathComponent().path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.configURL.path))

        let persistedConfig = try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: store.configURL))
        XCTAssertEqual(persistedConfig, .default)
    }

    func testSaveSyncsManagedConfigDirectoryAfterAtomicReplace() throws {
        let recorder = SyncOperationRecorder()
        let store = makeStore(syncFileDescriptorHandler: recorder.record)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        XCTAssertTrue(store.save(.default))
        XCTAssertEqual(
            recorder.operations,
            [
                "fsync temporary config",
                "fsync managed config directory"
            ]
        )
    }

    func testSaveSyncsParentDirectoryWhenManagedConfigDirectoryIsCreated() throws {
        let rootDirectoryURL = temporaryDirectoryURL.appendingPathComponent("nested/root", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        let recorder = SyncOperationRecorder()
        let store = ConfigStore(
            appSupportDirectory: rootDirectoryURL,
            syncFileDescriptorHandler: recorder.record
        )

        XCTAssertTrue(store.save(.default))
        XCTAssertEqual(
            recorder.operations,
            [
                "fsync temporary config",
                "fsync managed config directory",
                "fsync managed config parent directory"
            ]
        )
    }

    func testSaveFailureReturnsFalseWithoutCrashing() {
        let blockingFileURL = temporaryDirectoryURL.appendingPathComponent("blocking-file", isDirectory: false)
        XCTAssertNoThrow(try Data("blocked".utf8).write(to: blockingFileURL, options: .atomic))
        let store = ConfigStore(appSupportDirectory: blockingFileURL)

        XCTAssertFalse(store.save(.default))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.path))
    }

    func testSaveRejectsUnsupportedDurationsWithoutWritingConfig() {
        let store = makeStore()
        let invalidConfig = AppConfig(workDurationSeconds: 0.5, breakDurationSeconds: 20)

        XCTAssertFalse(store.save(invalidConfig))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.path))
    }

    func testSaveRejectsUnsupportedIdleAwayThresholdWithoutWritingConfig() {
        let store = makeStore()
        let invalidConfigs = [
            AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20, idleAwayResetThresholdSeconds: 0),
            AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20, idleAwayResetThresholdSeconds: -5),
            AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20, idleAwayResetThresholdSeconds: .infinity),
        ]

        invalidConfigs.forEach { invalidConfig in
            XCTAssertFalse(store.save(invalidConfig))
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.path))
    }

    func testSaveRejectsConfigThatWouldExceedLoadSizeLimit() {
        let store = makeStore()
        let oversizedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            breakOverlayMessageText: String(repeating: "x", count: 70_000)
        )

        XCTAssertFalse(store.save(oversizedConfig))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.path))
    }

    func testLoadFallbackBehaviorRemainsUnchangedAfterAddingSaveAPI() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: store.configURL, options: .atomic)

        XCTAssertEqual(store.load(), .default)
    }

    func testSaveRoundTripPreservesLaunchAtLoginEnabled() throws {
        let store = makeStore()
        let savedConfig = AppConfig(
            workDurationSeconds: 1_200,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: true
        )

        XCTAssertTrue(store.save(savedConfig))

        let persistedConfig = try JSONSerialization.jsonObject(
            with: Data(contentsOf: store.configURL)
        ) as? [String: Any]

        XCTAssertEqual(persistedConfig?["launchAtLoginEnabled"] as? Bool, true)
        XCTAssertEqual(store.load(), savedConfig)
    }

    private func makeStore(
        syncFileDescriptorHandler: @escaping (Int32, String) throws -> Void = ConfigStorePersistenceTests.liveSyncFileDescriptor
    ) -> ConfigStore {
        ConfigStore(
            appSupportDirectory: temporaryDirectoryURL,
            syncFileDescriptorHandler: syncFileDescriptorHandler
        )
    }

    private static func liveSyncFileDescriptor(_ fileDescriptor: Int32, operation _: String) throws {
        guard fsync(fileDescriptor) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }
}

private final class SyncOperationRecorder {
    private(set) var operations: [String] = []

    func record(fileDescriptor _: Int32, operation: String) throws {
        operations.append(operation)
    }
}
