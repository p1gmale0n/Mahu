import Foundation
import OSLog

struct ConfigStore {
    private static let logger = Logger(subsystem: "Mahu", category: "ConfigStore")

    private let appSupportDirectory: URL

    init(appSupportDirectory: URL? = nil) {
        let fileManager = FileManager.default
        self.appSupportDirectory = appSupportDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    var configURL: URL {
        appSupportDirectory
            .appendingPathComponent("Mahu", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    func load() -> AppConfig {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: configURL.path) {
            return createDefaultConfigFile()
        }

        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            guard config.hasSupportedDurations else {
                Self.logger.warning("Ignoring config at \(self.configURL.path, privacy: .public) because durations must be finite and at least one second.")
                return .default
            }

            return config
        } catch is DecodingError {
            return .default
        } catch {
            Self.logger.error("Failed to load config at \(self.configURL.path, privacy: .public): \(String(describing: error), privacy: .public)")
            return .default
        }
    }

    private func createDefaultConfigFile() -> AppConfig {
        do {
            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let defaultConfig = AppConfig.default
            let data = try JSONEncoder().encode(defaultConfig)
            try data.write(to: configURL, options: .atomic)
            return defaultConfig
        } catch {
            Self.logger.error("Failed to create default config at \(self.configURL.path, privacy: .public): \(String(describing: error), privacy: .public)")
            return .default
        }
    }
}
