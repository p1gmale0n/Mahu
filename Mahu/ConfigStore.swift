import Foundation
import OSLog

struct ConfigStore {
    private static let logger = Logger(subsystem: "Mahu", category: "ConfigStore")

    private let appSupportDirectory: URL

    init(
        appSupportDirectory: URL? = nil,
        appSupportDirectoryResolver: (() -> URL?)? = nil,
        fallbackHomeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        if let appSupportDirectory {
            self.appSupportDirectory = appSupportDirectory
            return
        }

        let resolvedAppSupportDirectory: URL?
        if let appSupportDirectoryResolver {
            resolvedAppSupportDirectory = appSupportDirectoryResolver()
        } else {
            resolvedAppSupportDirectory = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first
        }

        if let resolvedAppSupportDirectory {
            self.appSupportDirectory = resolvedAppSupportDirectory
            return
        }

        let fallbackDirectory = fallbackHomeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        Self.logger.error(
            "Failed to resolve the user Application Support directory; falling back to \(fallbackDirectory.path, privacy: .private)."
        )
        self.appSupportDirectory = fallbackDirectory
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
                Self.logger.warning(
                    "Ignoring config at \(self.configURL.path, privacy: .private) because durations must be finite, between \(Int(AppConfig.minimumSupportedDurationSeconds)) and \(Int64(AppConfig.maximumSupportedDurationSeconds)) seconds, and small enough to preserve one-second timer precision."
                )
                return .default
            }

            return config
        } catch let error as DecodingError {
            Self.logger.warning(
                "Ignoring config at \(self.configURL.path, privacy: .private) because it could not be decoded: \(String(describing: error), privacy: .public)"
            )
            return .default
        } catch {
            Self.logger.error("Failed to load config at \(self.configURL.path, privacy: .private): \(String(describing: error), privacy: .public)")
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
            Self.logger.error("Failed to create default config at \(self.configURL.path, privacy: .private): \(String(describing: error), privacy: .public)")
            return .default
        }
    }
}
