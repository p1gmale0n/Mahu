import AppKit
import Foundation
import OSLog

@MainActor
protocol BreakCompletionSoundPlaying: AnyObject {
    func playBreakCompletionSound()
}

protocol BreakCompletionSoundResource: AnyObject {
    func play() -> Bool
}

extension NSSound: BreakCompletionSoundResource {
}

@MainActor
final class BreakCompletionSoundPlayer: BreakCompletionSoundPlaying {
    typealias ResourceURLResolver = (Bundle) -> URL?
    typealias SoundResourceLoader = (URL) -> BreakCompletionSoundResource?
    typealias FileSizeProvider = (URL) throws -> Int

    private static let logger = Logger(subsystem: "Mahu", category: "BreakCompletionSoundPlayer")

    private let bundle: Bundle
    private let resolveResourceURL: ResourceURLResolver
    private let loadSoundResource: SoundResourceLoader
    private let fileSizeProvider: FileSizeProvider
    private var activeSound: BreakCompletionSoundResource?

    init(
        bundle: Bundle = .main,
        resolveResourceURL: @escaping ResourceURLResolver = { bundle in
            bundle.url(forResource: "sound", withExtension: "wav")
        },
        loadSoundResource: @escaping SoundResourceLoader = { url in
            NSSound(contentsOf: url, byReference: false)
        },
        fileSizeProvider: @escaping FileSizeProvider = { url in
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            return resourceValues.fileSize ?? 0
        }
    ) {
        self.bundle = bundle
        self.resolveResourceURL = resolveResourceURL
        self.loadSoundResource = loadSoundResource
        self.fileSizeProvider = fileSizeProvider
    }

    func playBreakCompletionSound() {
        guard let resourceURL = resolveResourceURL(bundle) else {
            Self.logger.warning("Missing bundled break completion sound resource.")
            return
        }

        do {
            let fileSize = try fileSizeProvider(resourceURL)
            guard fileSize > 0 else {
                Self.logger.warning("Break completion sound resource is empty.")
                return
            }
        } catch {
            Self.logger.warning("Failed to inspect break completion sound resource: \(error.localizedDescription, privacy: .public)")
            return
        }

        guard let sound = loadSoundResource(resourceURL) else {
            Self.logger.warning("Failed to decode bundled break completion sound resource.")
            return
        }

        activeSound = sound

        guard sound.play() else {
            Self.logger.warning("Failed to play bundled break completion sound resource.")
            return
        }
    }
}
