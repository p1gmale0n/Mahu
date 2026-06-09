import CoreGraphics
import XCTest
@testable import Mahu

final class ScreenLockStateProviderTests: XCTestCase {
    func testTreatsObservedLockedKeyAsLockedAway() {
        let provider = ScreenLockStateProvider(
            sessionDictionarySource: {
                self.makeSessionDictionary(onConsole: true, screenLocked: true)
            }
        )

        XCTAssertEqual(
            provider.currentState(),
            ScreenLockStateSnapshot(isScreenLocked: true, isOffConsole: false)
        )
        XCTAssertTrue(provider.isScreenLockedOrOffConsole())
    }

    func testTreatsMissingOrFalseLockKeyAsUnlockedWhenConsoleSessionIsUsable() {
        let missingLockKeyProvider = ScreenLockStateProvider(
            sessionDictionarySource: {
                self.makeSessionDictionary(onConsole: true)
            }
        )
        let falseLockKeyProvider = ScreenLockStateProvider(
            sessionDictionarySource: {
                self.makeSessionDictionary(onConsole: true, screenLocked: false)
            }
        )

        XCTAssertEqual(missingLockKeyProvider.currentState(), .unlocked)
        XCTAssertEqual(falseLockKeyProvider.currentState(), .unlocked)
        XCTAssertFalse(missingLockKeyProvider.isScreenLockedOrOffConsole())
        XCTAssertFalse(falseLockKeyProvider.isScreenLockedOrOffConsole())
    }

    func testTreatsNilDictionaryAsUnlocked() {
        let provider = ScreenLockStateProvider(sessionDictionarySource: { nil })

        XCTAssertEqual(provider.currentState(), .unlocked)
        XCTAssertFalse(provider.isScreenLockedOrOffConsole())
    }

    func testTreatsOffConsoleSessionAsLockedAway() {
        let provider = ScreenLockStateProvider(
            sessionDictionarySource: {
                self.makeSessionDictionary(onConsole: false)
            }
        )

        XCTAssertEqual(
            provider.currentState(),
            ScreenLockStateSnapshot(isScreenLocked: false, isOffConsole: true)
        )
        XCTAssertTrue(provider.isScreenLockedOrOffConsole())
    }

    func testTreatsLockedOffConsoleSessionAsTwoActiveAwaySources() {
        let provider = ScreenLockStateProvider(
            sessionDictionarySource: {
                self.makeSessionDictionary(onConsole: false, screenLocked: true)
            }
        )

        XCTAssertEqual(
            provider.currentState(),
            ScreenLockStateSnapshot(isScreenLocked: true, isOffConsole: true)
        )
        XCTAssertTrue(provider.isScreenLockedOrOffConsole())
    }

    func testTreatsUnknownSessionDictionaryValuesAsUnlocked() {
        let provider = ScreenLockStateProvider(
            sessionDictionarySource: {
                self.makeSessionDictionary(onConsole: "unknown", screenLocked: "unknown")
            }
        )

        XCTAssertEqual(provider.currentState(), .unlocked)
        XCTAssertFalse(provider.isScreenLockedOrOffConsole())
    }

    private func makeSessionDictionary(onConsole: Any? = nil, screenLocked: Any? = nil) -> NSDictionary {
        var dictionary: [String: Any] = [:]

        if let onConsole {
            dictionary[kCGSessionOnConsoleKey as String] = onConsole
        }

        if let screenLocked {
            dictionary["CGSSessionScreenIsLocked"] = screenLocked
        }

        return dictionary as NSDictionary
    }
}
