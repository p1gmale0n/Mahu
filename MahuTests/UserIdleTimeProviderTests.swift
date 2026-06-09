import CoreGraphics
import XCTest
@testable import Mahu

final class UserIdleTimeProviderTests: XCTestCase {
    func testNormalizedIdleDurationSecondsReturnsZeroForInvalidValues() {
        XCTAssertEqual(normalizedIdleDurationSeconds(.nan), 0)
        XCTAssertEqual(normalizedIdleDurationSeconds(.infinity), 0)
        XCTAssertEqual(normalizedIdleDurationSeconds(-.infinity), 0)
        XCTAssertEqual(normalizedIdleDurationSeconds(-1), 0)
    }

    func testSafeCurrentIdleDurationSecondsPreservesFiniteFakeProviderValue() {
        let provider = FakeUserIdleTimeProvider(idleDurationSeconds: 301.5)

        XCTAssertEqual(provider.safeCurrentIdleDurationSeconds(), 301.5)
    }

    func testSafeCurrentIdleDurationSecondsNormalizesInvalidFakeProviderValue() {
        let provider = FakeUserIdleTimeProvider(idleDurationSeconds: -.infinity)

        XCTAssertEqual(provider.safeCurrentIdleDurationSeconds(), 0)
    }

    func testLiveUserIdleTimeProviderUsesAnyInputHIDSourceByDefault() {
        var capturedStateID: CGEventSourceStateID?
        var capturedEventType: CGEventType?
        let provider = LiveUserIdleTimeProvider(currentIdleSecondsSource: { stateID, eventType in
            capturedStateID = stateID
            capturedEventType = eventType
            return 42.25
        })

        XCTAssertEqual(provider.currentIdleDurationSeconds(), 42.25)
        XCTAssertEqual(capturedStateID, .hidSystemState)
        XCTAssertEqual(capturedEventType?.rawValue, UInt32.max)
    }

    func testLiveUserIdleTimeProviderDefersNormalizationToSafeWrapper() {
        let provider = LiveUserIdleTimeProvider(currentIdleSecondsSource: { _, _ in -.infinity })

        XCTAssertEqual(provider.safeCurrentIdleDurationSeconds(), 0)
    }

    func testDefaultUserIdleTimeProviderReturnsZeroDuringTests() {
        var liveFactoryCallCount = 0
        let provider = makeDefaultUserIdleTimeProvider(environment: [
            "XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration"
        ], liveProviderFactory: {
            liveFactoryCallCount += 1
            return FakeUserIdleTimeProvider(idleDurationSeconds: 99)
        })

        XCTAssertEqual(provider.safeCurrentIdleDurationSeconds(), 0)
        XCTAssertEqual(liveFactoryCallCount, 0)
    }

    func testDefaultUserIdleTimeProviderUsesLiveFactoryOutsideTests() {
        let provider = makeDefaultUserIdleTimeProvider(
            environment: [:],
            liveProviderFactory: { FakeUserIdleTimeProvider(idleDurationSeconds: 42) }
        )

        XCTAssertEqual(provider.safeCurrentIdleDurationSeconds(), 42)
    }
}

private struct FakeUserIdleTimeProvider: UserIdleTimeProviding {
    let idleDurationSeconds: TimeInterval

    func currentIdleDurationSeconds() -> TimeInterval {
        idleDurationSeconds
    }
}
