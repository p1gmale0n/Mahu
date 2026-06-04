import Foundation
import XCTest
@testable import Mahu

final class ConfigStoreJSONCEdgeCaseTests: XCTestCase {
    private struct PreprocessedPayload: Decodable, Equatable {
        let items: [Int]
        let url: String
        let note: String
    }

    private struct SplitTokenPayload: Decodable {
        let value: Int
    }

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

    func testLoadFallsBackToDefaultsWhenBlockCommentSplitsNumberToken() throws {
        let store = makeStore()
        try writeRawConfig(
            """
            {
              "workDurationSeconds": 3/* comment */00,
              "breakDurationSeconds": 45
            }
            """,
            to: store.configURL
        )

        XCTAssertEqual(store.load(), .default)
    }

    func testLoadAcceptsTrailingLineCommentAtEndOfFileWithoutTerminalNewline() throws {
        let store = makeStore()
        try writeRawConfig(
            "{\n  \"workDurationSeconds\": 300,\n  \"breakDurationSeconds\": 45\n}// Relaunch keeps this note",
            to: store.configURL
        )

        XCTAssertEqual(store.load(), AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45))
    }

    func testLoadAcceptsSupportedUnicodeEncodingsForJSONC() throws {
        let rawJSON = """
        {
          // Unicode encoding coverage
          "workDurationSeconds": 300,
          "breakDurationSeconds": 45,
          "showStatusItemTimerState": true,
        }
        """
        let expectedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true
        )
        let utf16LEData = try XCTUnwrap(rawJSON.data(using: .utf16LittleEndian))
        let encodedCases: [(name: String, data: Data)] = [
            ("utf8-bom", Data([0xEF, 0xBB, 0xBF]) + Data(rawJSON.utf8)),
            ("utf16le", utf16LEData),
            ("utf16le-bom", Data([0xFF, 0xFE]) + utf16LEData),
        ]

        for encodedCase in encodedCases {
            let store = ConfigStore(
                appSupportDirectory: temporaryDirectoryURL.appendingPathComponent(encodedCase.name, isDirectory: true)
            )
            try writeRawConfigData(encodedCase.data, to: store.configURL)

            XCTAssertEqual(store.load(), expectedConfig, "Failed for \(encodedCase.name)")
        }
    }

    func testLoadFallsBackToDefaultsForInvalidUnicodeConfigData() throws {
        let store = makeStore()
        try writeRawConfigData(Data([0xFF, 0xFF, 0xFF, 0xFF]), to: store.configURL)

        XCTAssertEqual(store.load(), .default)
    }

    func testPreprocessorProducesDecodableJSONWithoutDamagingStrings() throws {
        let processedConfig = try ConfigJSONPreprocessor.preprocess(
            #"""
            {
              "items": [1, 2,],
              "url": "https://example.com/path//still-string",
              /* comment */
              "note": "text /* still string */",
            }
            """#
        )

        let payload = try JSONDecoder().decode(PreprocessedPayload.self, from: Data(processedConfig.utf8))

        XCTAssertEqual(
            payload,
            PreprocessedPayload(
                items: [1, 2],
                url: "https://example.com/path//still-string",
                note: "text /* still string */"
            )
        )
    }

    func testPreprocessorTreatsRemovedBlockCommentsAsWhitespaceBetweenTokens() throws {
        let processedConfig = try ConfigJSONPreprocessor.preprocess(#"{"value": 1/* comment */2}"#)

        XCTAssertThrowsError(try JSONDecoder().decode(SplitTokenPayload.self, from: Data(processedConfig.utf8)))
    }

    func testPreprocessorThrowsForUnterminatedBlockComment() {
        XCTAssertThrowsError(
            try ConfigJSONPreprocessor.preprocess(
                #"""
                {
                  "workDurationSeconds": 300,
                  /* comment never ends
                }
                """#
            )
        ) { error in
            XCTAssertEqual(error as? ConfigJSONPreprocessorError, .unterminatedBlockComment)
        }
    }

    private func makeStore() -> ConfigStore {
        ConfigStore(appSupportDirectory: temporaryDirectoryURL)
    }

    private func writeRawConfig(_ rawJSON: String, to url: URL) throws {
        try writeRawConfigData(Data(rawJSON.utf8), to: url)
    }

    private func writeRawConfigData(_ rawData: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try rawData.write(to: url, options: .atomic)
    }
}
