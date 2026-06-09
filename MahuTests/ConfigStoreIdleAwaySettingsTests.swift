import Foundation
import XCTest
@testable import Mahu

final class ConfigStoreIdleAwaySettingsTests: XCTestCase {
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

    func testDefaultConfigDisablesIdleAwayReset() {
        XCTAssertFalse(AppConfig.default.idleAwayResetEnabled)
    }

    func testDefaultConfigUsesDefaultIdleAwayResetThreshold() {
        XCTAssertEqual(AppConfig.default.idleAwayResetThresholdSeconds, AppConfig.defaultIdleAwayResetThresholdSeconds)
    }

    func testLoadReturnsIdleAwayDefaultsWhenJSONOmitsIdleAwayFields() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config.idleAwayResetEnabled, false)
        XCTAssertEqual(config.idleAwayResetThresholdSeconds, AppConfig.defaultIdleAwayResetThresholdSeconds)
    }

    func testLoadDecodesIdleAwayResetEnabledTrueWithCustomThreshold() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              // Keep this JSONC-editable.
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetEnabled": true,
              "idleAwayResetThresholdSeconds": 120,
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
                idleAwayResetEnabled: true,
                idleAwayResetThresholdSeconds: 120
            )
        )
    }

    func testLoadDefaultsIdleAwayThresholdWhenEnabledIsTrueAndThresholdIsOmitted() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetEnabled": true
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
                idleAwayResetEnabled: true,
                idleAwayResetThresholdSeconds: AppConfig.defaultIdleAwayResetThresholdSeconds
            )
        )
    }

    func testLoadDecodesIdleAwayResetEnabledFalseWithCustomThreshold() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetEnabled": false,
              "idleAwayResetThresholdSeconds": 900
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
                idleAwayResetEnabled: false,
                idleAwayResetThresholdSeconds: 900
            )
        )
    }

    func testLoadFallsBackToDefaultsWhenIdleAwayResetThresholdIsZero() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetThresholdSeconds": 0
            }
            """,
            to: store.configURL
        )

        XCTAssertEqual(store.load(), .default)
    }

    func testLoadFallsBackToDefaultsWhenIdleAwayResetThresholdIsNegative() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetThresholdSeconds": -5
            }
            """,
            to: store.configURL
        )

        XCTAssertEqual(store.load(), .default)
    }

    func testLoadFallsBackToDefaultsWhenIdleAwayResetEnabledIsNotBoolean() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetEnabled": "true"
            }
            """,
            to: store.configURL
        )

        XCTAssertEqual(store.load(), .default)
    }

    func testLoadFallsBackToDefaultsWhenIdleAwayResetEnabledIsNull() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetEnabled": null
            }
            """,
            to: store.configURL
        )

        XCTAssertEqual(store.load(), .default)
    }

    func testLoadFallsBackToDefaultsWhenIdleAwayResetThresholdIsNull() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetThresholdSeconds": null
            }
            """,
            to: store.configURL
        )

        XCTAssertEqual(store.load(), .default)
    }

    func testLoadFallsBackToDefaultsWhenIdleAwayResetThresholdIsNotNumeric() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "idleAwayResetThresholdSeconds": "300"
            }
            """,
            to: store.configURL
        )

        XCTAssertEqual(store.load(), .default)
    }

    func testLoadCreatesDefaultConfigFileWithIdleAwayDefaults() throws {
        let store = makeStore()

        _ = store.load()

        let fileData = try Data(contentsOf: store.configURL)
        let persistedConfig = try JSONSerialization.jsonObject(with: fileData) as? [String: Any]

        XCTAssertEqual(persistedConfig?["idleAwayResetEnabled"] as? Bool, false)
        XCTAssertEqual(
            persistedConfig?["idleAwayResetThresholdSeconds"] as? Double,
            AppConfig.defaultIdleAwayResetThresholdSeconds
        )
    }

    func testSaveRoundTripPreservesIdleAwayResetSettingsAsStrictJSON() throws {
        let store = makeStore()
        let savedConfig = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 45,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 180
        )

        XCTAssertTrue(store.save(savedConfig))

        let rawJSON = try XCTUnwrap(String(data: Data(contentsOf: store.configURL), encoding: .utf8))
        let persistedConfig = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(rawJSON.utf8)) as? [String: Any]
        )
        XCTAssertEqual(persistedConfig["idleAwayResetEnabled"] as? Bool, true)
        XCTAssertEqual(persistedConfig["idleAwayResetThresholdSeconds"] as? Double, 180)
        XCTAssertEqual(store.load(), savedConfig)
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
