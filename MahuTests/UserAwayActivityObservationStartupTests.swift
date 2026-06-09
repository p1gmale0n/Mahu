import AppKit
import XCTest
@testable import Mahu

@MainActor
final class UserAwayActivityObservationStartupTests: XCTestCase {
    func testSeededScreenLockedStateClearsOnFirstScreenUnlockNotification() {
        let screenLockNotificationCenter = NotificationCenter()
        let aggregationState = UserAwaySourceAggregationState()
        var events: [String] = []

        aggregationState.seedScreenLockedIfNeeded()

        let cancel = LiveUserAwayActivityObservationRegistrar.make(
            didBecomeAway: {
                events.append("away")
            },
            didBecomeActive: {
                events.append("active")
            },
            sessionActivityRegistrar: { _, _ in {} },
            screenLockRegistrar: { didBecomeAway, didBecomeActive in
                LiveScreenLockObservationRegistrar.make(
                    didLockScreen: didBecomeAway,
                    didUnlockScreen: didBecomeActive,
                    distributedNotificationCenter: screenLockNotificationCenter
                )
            },
            aggregationState: aggregationState
        )
        defer { cancel() }

        screenLockNotificationCenter.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        XCTAssertEqual(events, ["active"])
    }

    func testSeededStartupAwayStateStaysAwayUntilEverySeededSourceClears() {
        let sessionNotificationCenter = NotificationCenter()
        let screenLockNotificationCenter = NotificationCenter()
        let aggregationState = UserAwaySourceAggregationState()
        var events: [String] = []

        aggregationState.seedSessionAwayIfNeeded()
        aggregationState.seedScreenLockedIfNeeded()

        let cancel = LiveUserAwayActivityObservationRegistrar.make(
            didBecomeAway: {
                events.append("away")
            },
            didBecomeActive: {
                events.append("active")
            },
            sessionActivityRegistrar: { didBecomeAway, didBecomeActive in
                LiveSessionActivityObservationRegistrar.make(
                    didResignActive: didBecomeAway,
                    didBecomeActive: didBecomeActive,
                    workspaceNotificationCenter: sessionNotificationCenter
                )
            },
            screenLockRegistrar: { didBecomeAway, didBecomeActive in
                LiveScreenLockObservationRegistrar.make(
                    didLockScreen: didBecomeAway,
                    didUnlockScreen: didBecomeActive,
                    distributedNotificationCenter: screenLockNotificationCenter
                )
            },
            aggregationState: aggregationState
        )
        defer { cancel() }

        screenLockNotificationCenter.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        XCTAssertEqual(events, [])

        sessionNotificationCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        XCTAssertEqual(events, ["active"])
    }

    func testSingleScreenLockNotificationImmediatelyMarksUserAway() {
        let screenLockNotificationCenter = NotificationCenter()
        var events: [String] = []

        let cancel = LiveUserAwayActivityObservationRegistrar.make(
            didBecomeAway: {
                events.append("away")
            },
            didBecomeActive: {
                events.append("active")
            },
            sessionActivityRegistrar: { _, _ in {} },
            screenLockRegistrar: { didBecomeAway, didBecomeActive in
                LiveScreenLockObservationRegistrar.make(
                    didLockScreen: didBecomeAway,
                    didUnlockScreen: didBecomeActive,
                    distributedNotificationCenter: screenLockNotificationCenter
                )
            }
        )
        defer { cancel() }

        screenLockNotificationCenter.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)

        XCTAssertEqual(events, ["away"])
    }
}
