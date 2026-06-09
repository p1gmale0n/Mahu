import XCTest
@testable import Mahu

final class IdleAwayReconciliationPolicyTests: XCTestCase {
    func testIdleEpisodePolicyBelowThresholdDoesNotResetActiveWork() {
        var policy = IdleAwayEpisodePolicy()

        let action = policy.action(
            idleDurationSeconds: longSleepResetThresholdSeconds - 0.001,
            currentState: .init(phase: .work, remainingSeconds: 10),
            remindersPaused: false
        )

        XCTAssertEqual(action, .none)
    }

    func testIdleEpisodePolicyAtThresholdResetsActiveWorkWhenRemindersAreActive() {
        var policy = IdleAwayEpisodePolicy()

        let action = policy.action(
            idleDurationSeconds: longSleepResetThresholdSeconds,
            currentState: .init(phase: .work, remainingSeconds: 10),
            remindersPaused: false
        )

        XCTAssertEqual(action, .suppressElapsedAndReset(.resetActiveWork))
    }

    func testIdleEpisodePolicyAtThresholdPreservesPausedWork() {
        var policy = IdleAwayEpisodePolicy()

        let action = policy.action(
            idleDurationSeconds: longSleepResetThresholdSeconds,
            currentState: .init(phase: .work, remainingSeconds: 10),
            remindersPaused: true
        )

        XCTAssertEqual(action, .suppressElapsedAndReset(.preservePausedWork))
    }

    func testIdleEpisodePolicyAtThresholdResetsAfterActiveRest() {
        var policy = IdleAwayEpisodePolicy()

        let action = policy.action(
            idleDurationSeconds: longSleepResetThresholdSeconds,
            currentState: .init(phase: .rest, remainingSeconds: 10),
            remindersPaused: false
        )

        XCTAssertEqual(action, .suppressElapsedAndReset(.resetAfterActiveRest))
    }

    func testIdleEpisodePolicySuppressesRepeatedLongIdleUntilActivityRearms() {
        var policy = IdleAwayEpisodePolicy()

        XCTAssertEqual(
            policy.action(
                idleDurationSeconds: longSleepResetThresholdSeconds,
                currentState: .init(phase: .work, remainingSeconds: 10),
                remindersPaused: false
            ),
            .suppressElapsedAndReset(.resetActiveWork)
        )
        XCTAssertEqual(
            policy.action(
                idleDurationSeconds: longSleepResetThresholdSeconds + 5,
                currentState: .init(phase: .work, remainingSeconds: 10),
                remindersPaused: false
            ),
            .suppressElapsedOnly
        )
        XCTAssertEqual(
            policy.action(
                idleDurationSeconds: longSleepResetThresholdSeconds - 1,
                currentState: .init(phase: .work, remainingSeconds: 10),
                remindersPaused: false
            ),
            .none
        )
        XCTAssertEqual(
            policy.action(
                idleDurationSeconds: longSleepResetThresholdSeconds,
                currentState: .init(phase: .work, remainingSeconds: 10),
                remindersPaused: false
            ),
            .suppressElapsedAndReset(.resetActiveWork)
        )
    }

    func testLongAwayReconciliationReturnsNoneWhenStateIsMissing() {
        XCTAssertEqual(
            longAwayReconciliationAction(currentState: nil, remindersPaused: false),
            .none
        )
    }
}
