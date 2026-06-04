import Foundation
import XCTest
@testable import Mahu

final class ConfigStoreSizeLimitTests: XCTestCase {
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

    func testLoadAcceptsConfigAtExactSizeLimit() throws {
        let store = makeStore()
        let config = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try paddedConfigData(config: config, targetByteCount: 65_536)
            .write(to: store.configURL, options: .atomic)

        XCTAssertEqual(store.load(), config)
    }

    func testLoadRejectsConfigJustAboveSizeLimit() throws {
        let store = makeStore()
        let config = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 45)
        try FileManager.default.createDirectory(
            at: store.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try paddedConfigData(config: config, targetByteCount: 65_537)
            .write(to: store.configURL, options: .atomic)

        XCTAssertEqual(store.load(), .default)
    }

    private func makeStore() -> ConfigStore {
        ConfigStore(appSupportDirectory: temporaryDirectoryURL)
    }

    private func paddedConfigData(config: AppConfig, targetByteCount: Int) throws -> Data {
        let encodedConfig = try JSONEncoder().encode(config)
        precondition(encodedConfig.count <= targetByteCount, "Encoded config already exceeds the target byte count.")

        var paddedConfig = encodedConfig
        paddedConfig.append(Data(repeating: 0x20, count: targetByteCount - encodedConfig.count))
        return paddedConfig
    }
}
