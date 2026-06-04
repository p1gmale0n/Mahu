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

    func testDefaultConfigUsesDefaultBreakOverlayMessageText() {
        XCTAssertEqual(AppConfig.defaultBreakOverlayMessageText, "Время отвлечься")
        XCTAssertEqual(AppConfig.default.breakOverlayMessageText, "Время отвлечься")
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

    func testLoadReturnsDefaultBreakOverlayMessageWhenJSONOmitsMessageText() throws {
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
            AppConfig(
                workDurationSeconds: 300,
                breakDurationSeconds: 45,
                showStatusItemTimerState: false,
                breakOverlayMessageText: AppConfig.defaultBreakOverlayMessageText
            )
        )
    }

    func testLoadPreservesCustomUnicodeBreakOverlayMessageText() throws {
        let store = makeStore()
        let customMessage = "休憩しましょう — отдохни 🌿"
        try writeJSONObject(
            [
                "workDurationSeconds": 300,
                "breakDurationSeconds": 45,
                "breakOverlayMessageText": customMessage,
            ],
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config.breakOverlayMessageText, customMessage)
    }

    func testLoadNormalizesEmptyBreakOverlayMessageTextToDefault() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              \"workDurationSeconds\": 300,
              \"breakDurationSeconds\": 45,
              \"breakOverlayMessageText\": \"\"
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testLoadNormalizesWhitespaceOnlyBreakOverlayMessageTextToDefault() throws {
        let store = makeStore()
        try writeJSONObject(
            [
                "workDurationSeconds": 300,
                "breakDurationSeconds": 45,
                "breakOverlayMessageText": "   \n\t  ",
            ],
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
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

    func testLoadFallsBackToDefaultsWhenBreakOverlayMessageTextIsNull() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              \"workDurationSeconds\": 300,
              \"breakDurationSeconds\": 45,
              \"breakOverlayMessageText\": null
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsWhenBreakOverlayMessageTextIsNotAString() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              \"workDurationSeconds\": 300,
              \"breakDurationSeconds\": 45,
              \"breakOverlayMessageText\": 123
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

    func testLoadCreatesDefaultConfigFileWithDefaultBreakOverlayMessageText() throws {
        let store = makeStore()

        _ = store.load()

        let fileData = try Data(contentsOf: store.configURL)
        let persistedConfig = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]

        XCTAssertEqual(
            persistedConfig?["breakOverlayMessageText"] as? String,
            AppConfig.defaultBreakOverlayMessageText
        )
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

    private func writeJSONObject(_ object: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: object)
        try data.write(to: url, options: .atomic)
    }
}
