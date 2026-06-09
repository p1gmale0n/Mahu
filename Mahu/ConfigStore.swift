import Darwin
import Foundation
import OSLog

struct ConfigStore {
    private static let logger = Logger(subsystem: "Mahu", category: "ConfigStore")
    private static let maximumConfigFileBytes = 64 * 1024

    private enum ConfigLoadError: Error {
        case configFileTooLarge(maximumBytes: Int)
        case missingFileResourceType
    }

    private enum ConfigSaveError: Error {
        case symbolicLinkWritesAreUnsupported
        case managedConfigDirectoryMustBeDirectDirectory
        case posixFailure(operation: String, code: Int32)
    }

    private enum ConfigFileLocation {
        case missing
        case regularFile(URL)
        case invalidFileSystemObject
    }

    private let appSupportDirectory: URL
    private let syncFileDescriptorHandler: (Int32, String) throws -> Void

    init(
        appSupportDirectory: URL? = nil,
        appSupportDirectoryResolver: (() -> URL?)? = nil,
        fallbackHomeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        syncFileDescriptorHandler: @escaping (Int32, String) throws -> Void = ConfigStore.liveSyncFileDescriptor
    ) {
        self.syncFileDescriptorHandler = syncFileDescriptorHandler

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
        guard config.hasSupportedSettings else {
            Self.logger.warning(
                "Refusing to save config at \(self.configURL.path, privacy: .private) because durations must be finite, between \(Int(AppConfig.minimumSupportedDurationSeconds)) and \(Int64(AppConfig.maximumSupportedDurationSeconds)) seconds, small enough to preserve one-second timer precision, and idleAwayResetThresholdSeconds must be a positive finite number."
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

            try writeConfigDataAtomicallyWithoutFollowingSymlinks(data)
            return true
        } catch ConfigSaveError.symbolicLinkWritesAreUnsupported {
            Self.logger.warning(
                "Refusing to save config at \(self.configURL.path, privacy: .private) because the config path is a symbolic link. Update the target file directly instead."
            )
            return false
        } catch ConfigSaveError.managedConfigDirectoryMustBeDirectDirectory {
            Self.logger.warning(
                "Refusing to save config at \(self.configURL.path, privacy: .private) because the Mahu Application Support directory must be a real directory, not a symbolic link or another filesystem object."
            )
            return false
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
            let rawData = try loadConfigData(from: readableConfigURL)
            let preprocessedData = try ConfigJSONPreprocessor.preprocess(rawData)
            let config = try JSONDecoder().decode(AppConfig.self, from: preprocessedData)
            guard config.hasSupportedSettings else {
                Self.logger.warning(
                    "Ignoring config at \(self.configURL.path, privacy: .private) because durations must be finite, between \(Int(AppConfig.minimumSupportedDurationSeconds)) and \(Int64(AppConfig.maximumSupportedDurationSeconds)) seconds, small enough to preserve one-second timer precision, and idleAwayResetThresholdSeconds must be a positive finite number."
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
            let defaultConfig = AppConfig.default
            let data = try JSONEncoder().encode(defaultConfig)
            try writeConfigDataAtomicallyWithoutFollowingSymlinks(data)
            return defaultConfig
        } catch {
            Self.logger.error("Failed to create default config at \(self.configURL.path, privacy: .private): \(String(describing: error), privacy: .private)")
            return .default
        }
    }

    private func configFileLocation() -> ConfigFileLocation {
        guard validateManagedConfigDirectoryForLoad() else {
            return .invalidFileSystemObject
        }

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

    private func validateManagedConfigDirectoryForLoad() -> Bool {
        let managedConfigDirectoryURL = configURL.deletingLastPathComponent()

        do {
            let directoryResourceType = try fileResourceType(at: managedConfigDirectoryURL)
            guard directoryResourceType == .directory else {
                Self.logger.warning(
                    "Ignoring config at \(self.configURL.path, privacy: .private) because the Mahu Application Support directory must be a real directory, but found \(directoryResourceType.rawValue, privacy: .public)."
                )
                return false
            }

            return true
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return true
        } catch {
            Self.logger.error(
                "Failed to inspect Mahu config directory at \(managedConfigDirectoryURL.path, privacy: .private): \(String(describing: error), privacy: .private)"
            )
            return false
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

    private func writeConfigDataAtomicallyWithoutFollowingSymlinks(_ data: Data) throws {
        try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)

        let managedConfigDirectoryName = configURL.deletingLastPathComponent().lastPathComponent
        let configFileName = configURL.lastPathComponent
        let temporaryFileName = ".\(configFileName).tmp.\(UUID().uuidString)"
        let parentDirectoryFD = try openDirectoryFileDescriptor(at: appSupportDirectory)
        defer {
            _ = close(parentDirectoryFD)
        }

        let didCreateManagedConfigDirectory = try ensureManagedConfigDirectoryExists(
            named: managedConfigDirectoryName,
            in: parentDirectoryFD
        )
        let managedDirectoryFD = try openManagedConfigDirectory(named: managedConfigDirectoryName, in: parentDirectoryFD)
        defer {
            _ = close(managedDirectoryFD)
        }

        try ensureConfigEntryIsNotSymbolicLinkIfPresent(named: configFileName, in: managedDirectoryFD)

        var temporaryFileFD = try createTemporaryFile(named: temporaryFileName, in: managedDirectoryFD)
        var shouldRemoveTemporaryFile = true
        defer {
            if temporaryFileFD >= 0 {
                _ = close(temporaryFileFD)
            }

            if shouldRemoveTemporaryFile {
                temporaryFileName.withCString { temporaryFileNamePointer in
                    _ = unlinkat(managedDirectoryFD, temporaryFileNamePointer, 0)
                }
            }
        }

        try writeAll(data, to: temporaryFileFD)
        try syncFileDescriptor(temporaryFileFD, operation: "fsync temporary config")

        guard close(temporaryFileFD) == 0 else {
            throw ConfigSaveError.posixFailure(operation: "close temporary config", code: errno)
        }
        temporaryFileFD = -1

        try ensureConfigEntryIsNotSymbolicLinkIfPresent(named: configFileName, in: managedDirectoryFD)
        try replaceConfigEntryAtomically(
            from: temporaryFileName,
            to: configFileName,
            in: managedDirectoryFD
        )
        try syncFileDescriptor(managedDirectoryFD, operation: "fsync managed config directory")

        if didCreateManagedConfigDirectory {
            try syncFileDescriptor(parentDirectoryFD, operation: "fsync managed config parent directory")
        }

        shouldRemoveTemporaryFile = false
    }

    private func openDirectoryFileDescriptor(at url: URL) throws -> Int32 {
        let path = url.path
        let fileDescriptor = path.withCString { open($0, O_RDONLY | O_CLOEXEC | O_DIRECTORY | O_NOFOLLOW) }
        guard fileDescriptor >= 0 else {
            throw ConfigSaveError.posixFailure(operation: "open \(path)", code: errno)
        }

        return fileDescriptor
    }

    private func ensureManagedConfigDirectoryExists(named directoryName: String, in parentDirectoryFD: Int32) throws -> Bool {
        switch try directoryEntryType(named: directoryName, in: parentDirectoryFD) {
        case .none:
            let createResult = directoryName.withCString { mkdirat(parentDirectoryFD, $0, 0o700) }
            guard createResult == 0 || errno == EEXIST else {
                throw ConfigSaveError.posixFailure(operation: "mkdirat \(directoryName)", code: errno)
            }

            guard try directoryEntryType(named: directoryName, in: parentDirectoryFD) == .directory else {
                throw ConfigSaveError.managedConfigDirectoryMustBeDirectDirectory
            }
            return createResult == 0
        case .directory:
            return false
        case .symbolicLink, .regularFile, .other:
            throw ConfigSaveError.managedConfigDirectoryMustBeDirectDirectory
        }
    }

    private func openManagedConfigDirectory(named directoryName: String, in parentDirectoryFD: Int32) throws -> Int32 {
        let fileDescriptor = directoryName.withCString {
            openat(parentDirectoryFD, $0, O_RDONLY | O_CLOEXEC | O_DIRECTORY | O_NOFOLLOW)
        }

        guard fileDescriptor >= 0 else {
            if errno == ELOOP || errno == ENOTDIR {
                throw ConfigSaveError.managedConfigDirectoryMustBeDirectDirectory
            }

            throw ConfigSaveError.posixFailure(operation: "openat \(directoryName)", code: errno)
        }

        return fileDescriptor
    }

    private func ensureConfigEntryIsNotSymbolicLinkIfPresent(named fileName: String, in directoryFD: Int32) throws {
        guard try directoryEntryType(named: fileName, in: directoryFD) == .symbolicLink else {
            return
        }

        throw ConfigSaveError.symbolicLinkWritesAreUnsupported
    }

    private func createTemporaryFile(named fileName: String, in directoryFD: Int32) throws -> Int32 {
        let fileDescriptor = fileName.withCString {
            openat(directoryFD, $0, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        }

        guard fileDescriptor >= 0 else {
            throw ConfigSaveError.posixFailure(operation: "openat \(fileName)", code: errno)
        }

        return fileDescriptor
    }

    private func writeAll(_ data: Data, to fileDescriptor: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard var baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }

            var remainingByteCount = rawBuffer.count
            while remainingByteCount > 0 {
                let bytesWritten = write(fileDescriptor, baseAddress, remainingByteCount)
                if bytesWritten < 0 {
                    if errno == EINTR {
                        continue
                    }

                    throw ConfigSaveError.posixFailure(operation: "write config bytes", code: errno)
                }

                guard bytesWritten > 0 else {
                    throw ConfigSaveError.posixFailure(operation: "write config bytes", code: EIO)
                }

                remainingByteCount -= bytesWritten
                baseAddress = baseAddress.advanced(by: bytesWritten)
            }
        }
    }

    private func syncFileDescriptor(_ fileDescriptor: Int32, operation: String) throws {
        try syncFileDescriptorHandler(fileDescriptor, operation)
    }

    private static func liveSyncFileDescriptor(_ fileDescriptor: Int32, operation: String) throws {
        guard fsync(fileDescriptor) == 0 else {
            throw ConfigSaveError.posixFailure(operation: operation, code: errno)
        }
    }

    private func replaceConfigEntryAtomically(from temporaryFileName: String, to destinationFileName: String, in directoryFD: Int32) throws {
        let renameResult = temporaryFileName.withCString { temporaryFileNamePointer in
            destinationFileName.withCString { destinationFileNamePointer in
                renameat(directoryFD, temporaryFileNamePointer, directoryFD, destinationFileNamePointer)
            }
        }

        guard renameResult == 0 else {
            throw ConfigSaveError.posixFailure(operation: "renameat \(destinationFileName)", code: errno)
        }
    }

    private func directoryEntryType(named entryName: String, in directoryFD: Int32) throws -> DirectoryEntryType? {
        var entryStatus = stat()
        let statusResult = entryName.withCString {
            fstatat(directoryFD, $0, &entryStatus, AT_SYMLINK_NOFOLLOW)
        }

        guard statusResult == 0 else {
            if errno == ENOENT {
                return nil
            }

            throw ConfigSaveError.posixFailure(operation: "fstatat \(entryName)", code: errno)
        }

        switch entryStatus.st_mode & S_IFMT {
        case S_IFDIR:
            return .directory
        case S_IFREG:
            return .regularFile
        case S_IFLNK:
            return .symbolicLink
        default:
            return .other
        }
    }

    private enum DirectoryEntryType {
        case regularFile
        case directory
        case symbolicLink
        case other
    }
}
