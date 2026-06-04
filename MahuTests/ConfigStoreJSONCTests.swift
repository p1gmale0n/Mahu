import Foundation
import XCTest
@testable import Mahu

final class ConfigStoreJSONCTests: XCTestCase {
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

    func testLoadAcceptsLineCommentsInConfigJSON() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              // Short work interval for testing
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "showStatusItemTimerState": true
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

    func testLoadAcceptsBlockCommentsAndTrailingCommasInConfigJSON() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              /* Break duration stays short for manual relaunch checks. */
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "showStatusItemTimerState": true,
              "launchAtLoginEnabled": false,
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
                showStatusItemTimerState: true,
                launchAtLoginEnabled: false
            )
        )
    }

    func testLoadPreservesStringsContainingCommentLikeTextEscapedQuotesAndUnicode() throws {
        let store = makeStore()
        let customMessage = #"Focus // not a comment /* still text */ \"quoted\" https://example.com/пауза 🌿"#
        let encodedCustomMessage = try XCTUnwrap(
            String(data: try JSONEncoder().encode(customMessage), encoding: .utf8)
        )
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              "breakOverlayMessageText": \(encodedCustomMessage),
              // Keep the trailing comma to prove string safety during preprocessing.
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config.breakOverlayMessageText, customMessage)
    }

    func testLoadAcceptsJSONCThroughFinalConfigSymlinkWhenTargetIsRegularFile() throws {
        let store = makeStore()
        let sharedConfigURL = temporaryDirectoryURL.appendingPathComponent("shared-config.json", isDirectory: false)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 600,
              "breakDurationSeconds": 30,
              // Shared config stays human-editable.
              "showStatusItemTimerState": true,
            }
            """,
            to: sharedConfigURL,
            createParentDirectory: false
        )
        try FileManager.default.createSymbolicLink(at: store.configURL, withDestinationURL: sharedConfigURL)

        let config = store.load()

        XCTAssertEqual(
            config,
            AppConfig(workDurationSeconds: 600, breakDurationSeconds: 30, showStatusItemTimerState: true)
        )
    }

    func testLoadFallsBackToDefaultsForMalformedJSONCBlockComment() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              /* missing block comment terminator
              "breakDurationSeconds": 45
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsForExplicitInvalidFieldTypeInsideJSONC() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              // Wrong type must still fail through normal AppConfig decoding.
              "showStatusItemTimerState": "true"
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadDefaultsMissingOptionalFieldsAfterJSONCPreprocessing() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45, // Optional fields remain absent on purpose.
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
                breakOverlayMessageText: AppConfig.defaultBreakOverlayMessageText,
                launchAtLoginEnabled: false
            )
        )
    }

    func testLoadFallsBackToDefaultsForExplicitNullOptionalFieldInsideJSONC() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45,
              /* Null must keep the whole-config fallback path. */
              "breakOverlayMessageText": null
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadFallsBackToDefaultsForOversizedJSONCBeforeParsingCanSucceed() throws {
        let store = makeStore()
        let oversizedComment = String(repeating: "x", count: 70_000)
        try writeRawConfig(
            """
            {
              /* \(oversizedComment) */
              "workDurationSeconds": 300,
              "breakDurationSeconds": 45
            }
            """,
            to: store.configURL
        )

        let config = store.load()

        XCTAssertEqual(config, .default)
    }

    func testLoadPreservesStrictJSONBehaviorWithoutCommentsOrTrailingCommas() throws {
        let store = makeStore()
        let expectedConfig = AppConfig(
            workDurationSeconds: 900,
            breakDurationSeconds: 60,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Strict JSON",
            launchAtLoginEnabled: true
        )
        let encodedConfig = try XCTUnwrap(String(data: try JSONEncoder().encode(expectedConfig), encoding: .utf8))
        try writeRawConfig(encodedConfig, to: store.configURL)

        let config = store.load()

        XCTAssertEqual(config, expectedConfig)
    }

    private func makeStore() -> ConfigStore {
        ConfigStore(appSupportDirectory: temporaryDirectoryURL)
    }

    private func writeRawConfig(
        _ rawJSON: String,
        to url: URL,
        createParentDirectory: Bool = true
    ) throws {
        if createParentDirectory {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        try Data(rawJSON.utf8).write(to: url, options: .atomic)
    }
}
