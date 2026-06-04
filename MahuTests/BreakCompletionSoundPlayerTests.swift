import Foundation
import XCTest
@testable import Mahu

@MainActor
final class BreakCompletionSoundPlayerTests: XCTestCase {
    func testPlayDoesNothingWhenResourceIsMissing() {
        var loadCallCount = 0
        let player = BreakCompletionSoundPlayer(
            bundle: .main,
            resolveResourceURL: { _ in nil },
            loadSoundResource: { _ in
                loadCallCount += 1
                return nil
            }
        )

        player.playBreakCompletionSound()

        XCTAssertEqual(loadCallCount, 0)
    }

    func testPlayDoesNothingWhenResourceIsEmpty() throws {
        let emptyResourceURL = try makeTemporaryFile(data: Data())
        defer { try? FileManager.default.removeItem(at: emptyResourceURL) }

        var loadCallCount = 0
        let player = BreakCompletionSoundPlayer(
            bundle: .main,
            resolveResourceURL: { _ in emptyResourceURL },
            loadSoundResource: { _ in
                loadCallCount += 1
                return nil
            }
        )

        player.playBreakCompletionSound()

        XCTAssertEqual(loadCallCount, 0)
    }

    func testPlayDoesNothingWhenResourceCannotBeDecoded() throws {
        let invalidResourceURL = try makeTemporaryFile(data: Data([0x01, 0x02, 0x03]))
        defer { try? FileManager.default.removeItem(at: invalidResourceURL) }
        var loadedResourceURL: URL?
        var loadCallCount = 0

        let player = BreakCompletionSoundPlayer(
            bundle: .main,
            resolveResourceURL: { _ in invalidResourceURL },
            loadSoundResource: { url in
                loadedResourceURL = url
                loadCallCount += 1
                return nil
            }
        )

        player.playBreakCompletionSound()

        XCTAssertEqual(loadCallCount, 1)
        XCTAssertEqual(loadedResourceURL, invalidResourceURL)
    }

    func testPlayRetainsSoundResourceWhenPlaybackStarts() throws {
        let resourceURL = try makeTemporaryFile(data: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: resourceURL) }

        weak var weakSound: FakeBreakCompletionSoundResource?
        let player = BreakCompletionSoundPlayer(
            bundle: .main,
            resolveResourceURL: { _ in resourceURL },
            loadSoundResource: { _ in
                let sound = FakeBreakCompletionSoundResource(playResult: true)
                weakSound = sound
                return sound
            }
        )

        player.playBreakCompletionSound()

        XCTAssertEqual(weakSound?.playCallCount, 1)
        XCTAssertNotNil(weakSound)
    }

    func testPlayHandlesUnplayableSoundGracefully() throws {
        let resourceURL = try makeTemporaryFile(data: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: resourceURL) }

        let sound = FakeBreakCompletionSoundResource(playResult: false)
        let player = BreakCompletionSoundPlayer(
            bundle: .main,
            resolveResourceURL: { _ in resourceURL },
            loadSoundResource: { _ in sound }
        )

        player.playBreakCompletionSound()

        XCTAssertEqual(sound.playCallCount, 1)
    }

    func testPlayDoesNothingWhenResourceMetadataCannotBeRead() throws {
        let resourceURL = try makeTemporaryFile(data: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: resourceURL) }
        var loadCallCount = 0
        let player = BreakCompletionSoundPlayer(
            bundle: .main,
            resolveResourceURL: { _ in resourceURL },
            loadSoundResource: { _ in
                loadCallCount += 1
                return nil
            },
            fileSizeProvider: { _ in
                throw TestSoundMetadataError.failedToReadFileSize
            }
        )

        player.playBreakCompletionSound()

        XCTAssertEqual(loadCallCount, 0)
    }

    private func makeTemporaryFile(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        return url
    }
}

private enum TestSoundMetadataError: Error {
    case failedToReadFileSize
}

private final class FakeBreakCompletionSoundResource: NSObject, BreakCompletionSoundResource {
    private(set) var playCallCount = 0
    private let playResult: Bool

    init(playResult: Bool) {
        self.playResult = playResult
    }

    func play() -> Bool {
        playCallCount += 1
        return playResult
    }
}
