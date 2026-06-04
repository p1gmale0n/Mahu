import Darwin
import Foundation
import XCTest
@testable import Mahu

final class ConfigStoreTests: XCTestCase {
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

    func testDefaultConfigValues() {
        XCTAssertEqual(AppConfig.default.workDurationSeconds, 1_200)
        XCTAssertEqual(AppConfig.default.breakDurationSeconds, 20)
    }

    func testConfigURLUsesMahuConfigJSONPath() {
        let store = makeStore()

        XCTAssertEqual(store.configURL.lastPathComponent, "config.json")
        XCTAssertEqual(store.configURL.deletingLastPathComponent().lastPathComponent, "Mahu")
        XCTAssertEqual(store.configURL.path, temporaryDirectoryURL.appendingPathComponent("Mahu/config.json").path)
    }

    func testLoadCreatesMissingDefaultConfigFile() throws {
        let store = makeStore()

        let config = store.load()

        XCTAssertEqual(config, .default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.configURL.path))

        let fileData = try Data(contentsOf: store.configURL)
        let persistedConfig = try JSONDecoder().decode(AppConfig.self, from: fileData)
        XCTAssertEqual(persistedConfig, .default)
    }

    func testLoadReturnsCustomConfigFromDisk() throws {
        let store = makeStore()
        let customConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(customConfig)
        try data.write(to: store.configURL, options: .atomic)

        let config = store.load()

        XCTAssertEqual(config, customConfig)
    }

    func testLoadReturnsCustomConfigFromRegularFileSymlink() throws {
        let store = makeStore()
        let customConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45)
        let realConfigURL = temporaryDirectoryURL.appendingPathComponent("shared-config.json", isDirectory: false)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(customConfig)
        try data.write(to: realConfigURL, options: .atomic)
        try FileManager.default.createSymbolicLink(at: store.configURL, withDestinationURL: realConfigURL)

        let config = store.load()

        XCTAssertEqual(config, customConfig)
    }

    func testLoadFallsBackToDefaultsWhenMahuConfigDirectoryIsASymlink() throws {
        let store = makeStore()
        let sharedDirectoryURL = temporaryDirectoryURL.appendingPathComponent("shared-config-directory", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent().deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: store.configURL.deletingLastPathComponent(),
            withDestinationURL: sharedDirectoryURL
        )
        let data = try JSONEncoder().encode(AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45))
        try data.write(to: sharedDirectoryURL.appendingPathComponent("config.json"), options: .atomic)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenConfigSymlinkTargetIsMissing() throws {
        let store = makeStore()
        let missingConfigURL = temporaryDirectoryURL.appendingPathComponent("missing-config.json", isDirectory: false)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: store.configURL, withDestinationURL: missingConfigURL)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenConfigSymlinkTargetIsDirectory() throws {
        let store = makeStore()
        let sharedDirectoryURL = temporaryDirectoryURL.appendingPathComponent("shared-config", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: store.configURL, withDestinationURL: sharedDirectoryURL)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenConfigSymlinkTargetCannotBeRead() throws {
        let store = makeStore()
        let customConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45)
        let realConfigURL = temporaryDirectoryURL.appendingPathComponent("protected-config.json", isDirectory: false)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(customConfig).write(to: realConfigURL, options: .atomic)
        XCTAssertEqual(chmod(realConfigURL.path, 0o000), 0)
        defer {
            _ = chmod(realConfigURL.path, 0o600)
        }

        try FileManager.default.createSymbolicLink(at: store.configURL, withDestinationURL: realConfigURL)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsForInvalidConfig() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: store.configURL, options: .atomic)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsForNonPositiveConfigDurations() throws {
        let store = makeStore()
        let invalidConfig = AppConfig(workDurationSeconds: 0, breakDurationSeconds: -5)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(invalidConfig)
        try data.write(to: store.configURL, options: .atomic)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsForSubsecondConfigDurations() throws {
        let store = makeStore()
        let invalidConfig = AppConfig(workDurationSeconds: 0.5, breakDurationSeconds: 0.25)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(invalidConfig)
        try data.write(to: store.configURL, options: .atomic)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadReturnsFiniteConfigDurationsLongerThanTwentyFourHours() throws {
        let store = makeStore()
        let longConfig = AppConfig(
            workDurationSeconds: 172_800,
            breakDurationSeconds: 90_000
        )
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(longConfig)
        try data.write(to: store.configURL, options: .atomic)

        let config = store.load()

        XCTAssertEqual(config, longConfig)
    }

    func testLoadFallsBackToDefaultsForConfigDurationsAboveSecondPrecisionLimit() throws {
        let store = makeStore()
        let invalidConfig = AppConfig(workDurationSeconds: 1e20, breakDurationSeconds: 20)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(invalidConfig)
        try data.write(to: store.configURL, options: .atomic)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenExistingConfigCannotBeRead() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: store.configURL, withIntermediateDirectories: true)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenConfigExceedsSizeLimit() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x61, count: 70_000).write(to: store.configURL, options: .atomic)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenConfigPathIsNamedPipe() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        XCTAssertEqual(mkfifo(store.configURL.path, 0o600), 0)

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenDefaultConfigCannotBeWritten() throws {
        let blockingFileURL = temporaryDirectoryURL.appendingPathComponent("blocking-file", isDirectory: false)
        try Data("blocked".utf8).write(to: blockingFileURL, options: .atomic)
        let store = ConfigStore(appSupportDirectory: blockingFileURL)

        let config = store.load()

        XCTAssertEqual(config, .default)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.path))
    }

    func testInitFallsBackToHomeLibraryApplicationSupportWhenSystemLookupFails() {
        let fallbackHomeDirectory = temporaryDirectoryURL.appendingPathComponent("FallbackHome", isDirectory: true)
        let store = ConfigStore(
            appSupportDirectoryResolver: { nil },
            fallbackHomeDirectory: fallbackHomeDirectory
        )

        XCTAssertEqual(
            store.configURL.path,
            fallbackHomeDirectory
                .appendingPathComponent("Library/Application Support/Mahu/config.json")
                .path
        )
    }

    private func makeStore() -> ConfigStore {
        ConfigStore(appSupportDirectory: temporaryDirectoryURL)
    }
}
