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

    private func makeStore() -> ConfigStore {
        ConfigStore(appSupportDirectory: temporaryDirectoryURL)
    }
}
