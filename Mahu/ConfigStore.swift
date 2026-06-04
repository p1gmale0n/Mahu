import Foundation
import OSLog

struct ConfigStore {
    private static let logger = Logger(subsystem: "Mahu", category: "ConfigStore")
    private static let maximumConfigFileBytes = 64 * 1024

    private enum ConfigLoadError: Error {
        case configFileTooLarge(maximumBytes: Int)
        case missingFileResourceType
    }

    private enum ConfigFileLocation {
        case missing
        case regularFile(URL)
        case invalidFileSystemObject
    }

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

    @discardableResult
    func save(_ config: AppConfig) -> Bool {
        guard config.hasSupportedDurations else {
            Self.logger.warning(
                "Refusing to save config at \(self.configURL.path, privacy: .private) because durations must be finite, between \(Int(AppConfig.minimumSupportedDurationSeconds)) and \(Int64(AppConfig.maximumSupportedDurationSeconds)) seconds, and small enough to preserve one-second timer precision."
            )
            return false
        }

        do {
            let data = try JSONEncoder().encode(config)
            guard data.count <= Self.maximumConfigFileBytes else {
                Self.logger.warning(
                    "Refusing to save config at \(self.configURL.path, privacy: .private) because the encoded JSON exceeds the supported size limit of \(Self.maximumConfigFileBytes, privacy: .public) bytes."
                )
                return false
            }

            let writableConfigURL = try resolvedWritableConfigURL()
            try FileManager.default.createDirectory(
                at: writableConfigURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: writableConfigURL, options: .atomic)
            return true
        } catch {
            Self.logger.error(
                "Failed to save config at \(self.configURL.path, privacy: .private): \(String(describing: error), privacy: .private)"
            )
            return false
        }
    }

    func load() -> AppConfig {
        switch configFileLocation() {
        case .missing:
            return createDefaultConfigFile()
        case .invalidFileSystemObject:
            return .default
        case .regularFile(let readableConfigURL):
            return loadRegularConfig(from: readableConfigURL)
        }
    }

    private func loadRegularConfig(from readableConfigURL: URL) -> AppConfig {
        do {
            let data = try loadConfigData(from: readableConfigURL)
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            guard config.hasSupportedDurations else {
                Self.logger.warning(
                    "Ignoring config at \(self.configURL.path, privacy: .private) because durations must be finite, between \(Int(AppConfig.minimumSupportedDurationSeconds)) and \(Int64(AppConfig.maximumSupportedDurationSeconds)) seconds, and small enough to preserve one-second timer precision."
                )
                return .default
            }

            return config
        } catch ConfigLoadError.configFileTooLarge(let maximumBytes) {
            Self.logger.warning(
                "Ignoring config at \(self.configURL.path, privacy: .private) because it exceeds the supported size limit of \(maximumBytes, privacy: .public) bytes."
            )
            return .default
        } catch let error as DecodingError {
            Self.logger.warning(
                "Ignoring config at \(self.configURL.path, privacy: .private) because it could not be decoded: \(String(describing: error), privacy: .public)"
            )
            return .default
        } catch {
            Self.logger.error("Failed to load config at \(self.configURL.path, privacy: .private): \(String(describing: error), privacy: .private)")
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
            Self.logger.error("Failed to create default config at \(self.configURL.path, privacy: .private): \(String(describing: error), privacy: .private)")
            return .default
        }
    }

    private func resolvedWritableConfigURL() throws -> URL {
        do {
            let configResourceType = try fileResourceType(at: configURL)
            guard configResourceType == .symbolicLink else {
                return configURL
            }

            return configURL.resolvingSymlinksInPath()
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return configURL
        }
    }

    private func configFileLocation() -> ConfigFileLocation {
        do {
            let configResourceType = try fileResourceType(at: configURL)
            switch configResourceType {
            case .regular:
                return .regularFile(configURL)
            case .symbolicLink:
                return resolvedSymbolicLinkConfigFileLocation()
            default:
                Self.logger.warning(
                    "Ignoring config at \(self.configURL.path, privacy: .private) because it must be a regular file, but found \(configResourceType.rawValue, privacy: .public)."
                )
                return .invalidFileSystemObject
            }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            Self.logger.error(
                "Failed to inspect config at \(self.configURL.path, privacy: .private): \(String(describing: error), privacy: .private)"
            )
            return .invalidFileSystemObject
        }
    }

    private func resolvedSymbolicLinkConfigFileLocation() -> ConfigFileLocation {
        let resolvedConfigURL = configURL.resolvingSymlinksInPath()

        do {
            let resolvedResourceType = try fileResourceType(at: resolvedConfigURL)
            guard resolvedResourceType == .regular else {
                Self.logger.warning(
                    "Ignoring config symlink at \(self.configURL.path, privacy: .private) because it resolves to \(resolvedResourceType.rawValue, privacy: .public) instead of a regular file."
                )
                return .invalidFileSystemObject
            }

            return .regularFile(resolvedConfigURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            Self.logger.warning(
                "Ignoring config symlink at \(self.configURL.path, privacy: .private) because its target is missing."
            )
            return .invalidFileSystemObject
        } catch {
            Self.logger.error(
                "Failed to inspect config symlink at \(self.configURL.path, privacy: .private): \(String(describing: error), privacy: .private)"
            )
            return .invalidFileSystemObject
        }
    }

    private func fileResourceType(at url: URL) throws -> URLFileResourceType {
        let resourceValues = try url.resourceValues(forKeys: [.fileResourceTypeKey])
        guard let resourceType = resourceValues.fileResourceType else {
            throw ConfigLoadError.missingFileResourceType
        }

        return resourceType
    }

    private func loadConfigData(from readableConfigURL: URL) throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: readableConfigURL)
        defer {
            try? fileHandle.close()
        }

        var data = Data()
        while true {
            let chunk = try fileHandle.read(upToCount: 4_096) ?? Data()
            guard chunk.isEmpty == false else {
                return data
            }

            data.append(chunk)
            guard data.count <= Self.maximumConfigFileBytes else {
                throw ConfigLoadError.configFileTooLarge(maximumBytes: Self.maximumConfigFileBytes)
            }
        }
    }
}
