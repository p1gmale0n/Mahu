import Foundation

struct ConfigStore {
    private let fileManager: FileManager
    private let appSupportDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileManager = fileManager
        self.appSupportDirectory = appSupportDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.encoder = encoder
        self.decoder = decoder
    }

    var configURL: URL {
        appSupportDirectory
            .appendingPathComponent("Mahu", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    func load() -> AppConfig {
        do {
            if !fileManager.fileExists(atPath: configURL.path) {
                return try createDefaultConfigFile()
            }

            let data = try Data(contentsOf: configURL)
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            return .default
        }
    }

    @discardableResult
    private func createDefaultConfigFile() throws -> AppConfig {
        try fileManager.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let defaultConfig = AppConfig.default
        let data = try encoder.encode(defaultConfig)
        try data.write(to: configURL, options: .atomic)
        return defaultConfig
    }
}
