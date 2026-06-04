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
            breakOverlayMessageText: "Saved config"
        )

        XCTAssertTrue(store.save(savedConfig))
        XCTAssertEqual(store.load(), savedConfig)
    }

    func testSavePreservesConfigSymlinkAndUpdatesItsTarget() throws {
        let store = makeStore()
        let sharedConfigURL = temporaryDirectoryURL.appendingPathComponent("shared-config.json", isDirectory: false)
        let initialConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let savedConfig = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Saved via symlink"
        )

        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(initialConfig).write(to: sharedConfigURL, options: .atomic)
        try FileManager.default.createSymbolicLink(at: store.configURL, withDestinationURL: sharedConfigURL)

        XCTAssertTrue(store.save(savedConfig))

        let configResourceType = try XCTUnwrap(
            store.configURL.resourceValues(forKeys: [.fileResourceTypeKey]).fileResourceType
        )
        XCTAssertEqual(configResourceType, .symbolicLink)
        let persistedConfig = try JSONDecoder().decode(AppConfig.self, from: Data(contentsOf: sharedConfigURL))
        XCTAssertEqual(persistedConfig, savedConfig)
        XCTAssertEqual(store.load(), savedConfig)
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

    private func makeStore() -> ConfigStore {
        ConfigStore(appSupportDirectory: temporaryDirectoryURL)
    }
}
