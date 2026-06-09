import CoreGraphics
import Foundation

struct ScreenLockStateSnapshot: Equatable {
    let isScreenLocked: Bool
    let isOffConsole: Bool

    static let unlocked = ScreenLockStateSnapshot(
        isScreenLocked: false,
        isOffConsole: false
    )

    var isUserAway: Bool {
        isScreenLocked || isOffConsole
    }
}

protocol ScreenLockStateProviding {
    func isScreenLockedOrOffConsole() -> Bool
    func currentState() -> ScreenLockStateSnapshot
}

extension ScreenLockStateProviding {
    func currentState() -> ScreenLockStateSnapshot {
        if isScreenLockedOrOffConsole() {
            return ScreenLockStateSnapshot(
                isScreenLocked: true,
                isOffConsole: false
            )
        }

        return .unlocked
    }
}

struct ScreenLockStateProvider: ScreenLockStateProviding {
    typealias SessionDictionarySource = () -> NSDictionary?

    // Observed session key; CGSessionCopyCurrentDictionary() remains the public API boundary.
    private static let observedScreenLockedKey = "CGSSessionScreenIsLocked"

    private let sessionDictionarySource: SessionDictionarySource

    init(sessionDictionarySource: @escaping SessionDictionarySource = {
        CGSessionCopyCurrentDictionary() as NSDictionary?
    }) {
        self.sessionDictionarySource = sessionDictionarySource
    }

    func isScreenLockedOrOffConsole() -> Bool {
        currentState().isUserAway
    }

    func currentState() -> ScreenLockStateSnapshot {
        guard let sessionDictionary = sessionDictionarySource() else {
            return .unlocked
        }

        let isOffConsole = sessionDictionary[kCGSessionOnConsoleKey as String] as? Bool == false
        let isScreenLocked = sessionDictionary[Self.observedScreenLockedKey] as? Bool == true

        return ScreenLockStateSnapshot(
            isScreenLocked: isScreenLocked,
            isOffConsole: isOffConsole
        )
    }
}
