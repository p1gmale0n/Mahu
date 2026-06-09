import AppKit
import XCTest
@testable import Mahu

@MainActor
final class LiveSessionActivityObservationRegistrarTests: XCTestCase {
    func testSessionDidResignActiveNotificationTriggersHandlerSynchronously() {
        let context = makeRegistrarContext(
            didResignActive: {},
            didBecomeActive: {}
        )
        defer { context.cancel() }

        context.notificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)

        XCTAssertEqual(context.didResignActiveCallCount(), 1)
        XCTAssertEqual(context.didBecomeActiveCallCount(), 0)
    }

    func testSessionDidBecomeActiveNotificationTriggersHandlerSynchronously() {
        let context = makeRegistrarContext(didResignActive: {}, didBecomeActive: {})
        defer { context.cancel() }

        context.notificationCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        XCTAssertEqual(context.didResignActiveCallCount(), 0)
        XCTAssertEqual(context.didBecomeActiveCallCount(), 1)
    }

    func testBackgroundPostedNotificationsSynchronouslyHopToMainActorBeforeReturning() async {
        let orderQueue = DispatchQueue(label: "LiveSessionActivityObservationRegistrarTests.eventOrder")
        var eventOrder: [String] = []
        let context = makeRegistrarContext(
            didResignActive: {
                orderQueue.sync {
                    eventOrder.append("handler")
                }
            },
            didBecomeActive: {}
        )
        defer { context.cancel() }

        let completion = expectation(description: "background post completed")

        DispatchQueue.global(qos: .userInitiated).async {
            context.notificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
            orderQueue.sync {
                eventOrder.append("post-returned")
            }
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 1.0)

        let recordedOrder = orderQueue.sync { eventOrder }
        XCTAssertEqual(recordedOrder, ["handler", "post-returned"])
        XCTAssertEqual(context.didResignActiveCallCount(), 1)
        XCTAssertEqual(context.didBecomeActiveCallCount(), 0)
    }

    func testCancelIsIdempotentAndStopsFutureEvents() async {
        let unexpectedSessionChange = expectation(description: "session activity should stay cancelled")
        unexpectedSessionChange.isInverted = true
        let context = makeRegistrarContext(
            didResignActive: {
                unexpectedSessionChange.fulfill()
            },
            didBecomeActive: {
                unexpectedSessionChange.fulfill()
            }
        )

        context.cancel()
        context.cancel()
        context.notificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        context.notificationCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        await fulfillment(of: [unexpectedSessionChange], timeout: 0.1)
        XCTAssertEqual(context.didResignActiveCallCount(), 0)
        XCTAssertEqual(context.didBecomeActiveCallCount(), 0)
    }

    func testProductionFactoryUsesSharedWorkspaceNotificationCenter() {
        var didResignActiveCallCount = 0
        var didBecomeActiveCallCount = 0
        let cancel = LiveSessionActivityObservationRegistrar.make(
            didResignActive: {
                didResignActiveCallCount += 1
            },
            didBecomeActive: {
                didBecomeActiveCallCount += 1
            }
        )
        defer { cancel() }

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: NSWorkspace.shared
        )
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: NSWorkspace.shared
        )

        XCTAssertEqual(didResignActiveCallCount, 1)
        XCTAssertEqual(didBecomeActiveCallCount, 1)
    }

    func testCombinedRegistrarStillMapsSessionSwitchNotificationsToAwayAndActiveCallbacks() {
        let sessionNotificationCenter = NotificationCenter()
        let screenLockNotificationCenter = NotificationCenter()
        var didBecomeAwayCallCount = 0
        var didBecomeActiveCallCount = 0

        let cancel = LiveUserAwayActivityObservationRegistrar.make(
            didBecomeAway: {
                didBecomeAwayCallCount += 1
            },
            didBecomeActive: {
                didBecomeActiveCallCount += 1
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
            }
        )
        defer { cancel() }

        sessionNotificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        sessionNotificationCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        XCTAssertEqual(didBecomeAwayCallCount, 1)
        XCTAssertEqual(didBecomeActiveCallCount, 1)
    }

    func testCombinedRegistrarKeepsAwayUntilEverySourceClears() {
        let sessionNotificationCenter = NotificationCenter()
        let screenLockNotificationCenter = NotificationCenter()
        var events: [String] = []
        let screenLockStateProvider = ScriptedScreenLockStateProvider([true, false])

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
            screenLockStateProvider: screenLockStateProvider
        )
        defer { cancel() }

        sessionNotificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        screenLockNotificationCenter.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        sessionNotificationCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        XCTAssertEqual(events, ["away"])

        screenLockNotificationCenter.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        XCTAssertEqual(events, ["away", "active"])
    }

    func testCombinedRegistrarCancelIsIdempotentAndStopsSessionAndScreenLockSources() {
        let sessionNotificationCenter = NotificationCenter()
        let screenLockNotificationCenter = NotificationCenter()
        var didBecomeAwayCallCount = 0
        var didBecomeActiveCallCount = 0

        let cancel = LiveUserAwayActivityObservationRegistrar.make(
            didBecomeAway: {
                didBecomeAwayCallCount += 1
            },
            didBecomeActive: {
                didBecomeActiveCallCount += 1
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
            }
        )

        cancel()
        cancel()
        sessionNotificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        sessionNotificationCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        screenLockNotificationCenter.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        screenLockNotificationCenter.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        XCTAssertEqual(didBecomeAwayCallCount, 0)
        XCTAssertEqual(didBecomeActiveCallCount, 0)
    }

    func testCombinedRegistrarTreatsScreenLockNotificationsAsImmediateAwayAndActiveEdges() {
        let screenLockNotificationCenter = NotificationCenter()
        var events: [String] = []

        let cancel = LiveUserAwayActivityObservationRegistrar.make(
            didBecomeAway: {
                events.append("away")
            },
            didBecomeActive: {
                events.append("active")
            },
            sessionActivityRegistrar: { _, _ in
                {}
            },
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

        screenLockNotificationCenter.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        XCTAssertEqual(events, ["away", "active"])
    }

    private func makeRegistrarContext(
        didResignActive: @escaping @MainActor () -> Void = {},
        didBecomeActive: @escaping @MainActor () -> Void = {}
    ) -> (
        notificationCenter: NotificationCenter,
        didResignActiveCallCount: () -> Int,
        didBecomeActiveCallCount: () -> Int,
        cancel: SessionActivityObservationCancellation
    ) {
        let notificationCenter = NotificationCenter()
        var didResignActiveCallCount = 0
        var didBecomeActiveCallCount = 0

        let cancel = LiveSessionActivityObservationRegistrar.make(
            didResignActive: {
                didResignActiveCallCount += 1
                didResignActive()
            },
            didBecomeActive: {
                didBecomeActiveCallCount += 1
                didBecomeActive()
            },
            workspaceNotificationCenter: notificationCenter
        )

        return (
            notificationCenter,
            { didResignActiveCallCount },
            { didBecomeActiveCallCount },
            cancel
        )
    }
}

private final class ScriptedScreenLockStateProvider: ScreenLockStateProviding {
    private var values: [Bool]
    private let fallbackValue: Bool

    init(_ values: [Bool]) {
        self.values = values
        fallbackValue = values.last ?? false
    }

    func isScreenLockedOrOffConsole() -> Bool {
        guard values.isEmpty == false else {
            return fallbackValue
        }

        return values.removeFirst()
    }
}
