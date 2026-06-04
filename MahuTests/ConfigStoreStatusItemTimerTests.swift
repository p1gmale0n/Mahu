import Foundation
import XCTest
@testable import Mahu

final class ConfigStoreStatusItemTimerTests: XCTestCase {
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

    func testDefaultConfigDisablesStatusItemTimerState() {
        XCTAssertFalse(AppConfig.default.showStatusItemTimerState)
    }

    func testLoadReturnsIconOnlyModeWhenJSONOmitsStatusItemTimerState() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              \"workDurationSeconds\": 300,
              \"breakDurationSeconds\": 45
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(
            config,
            AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45, showStatusItemTimerState: false)
        )
    }

    func testLoadEnablesStatusItemTimerStateWhenJSONSetsTrue() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              \"workDurationSeconds\": 300,
              \"breakDurationSeconds\": 45,
              \"showStatusItemTimerState\": true
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(
            config,
            AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45, showStatusItemTimerState: true)
        )
    }

    func testLoadFallsBackToDefaultsWhenStatusItemTimerStateIsNotBoolean() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              \"workDurationSeconds\": 300,
              \"breakDurationSeconds\": 45,
              \"showStatusItemTimerState\": \"true\"
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenStatusItemTimerStateIsNull() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              \"workDurationSeconds\": 300,
              \"breakDurationSeconds\": 45,
              \"showStatusItemTimerState\": null
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadCreatesDefaultConfigFileWithStatusItemTimerStateSetToFalse() throws {
        let store = makeStore()

        _ = store.load()

        let fileData = try Data(contentsOf: store.configURL)
        let persistedConfig = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]

        XCTAssertEqual(persistedConfig?["showStatusItemTimerState"] as? Bool, false)
    }

    private func makeStore() -> ConfigStore {
        ConfigStore(appSupportDirectory: temporaryDirectoryURL)
    }

    private func writeRawConfig(_ rawJSON: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(rawJSON.utf8).write(to: url, options: .atomic)
    }
}
