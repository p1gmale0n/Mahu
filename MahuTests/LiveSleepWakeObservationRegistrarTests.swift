import AppKit
import XCTest
@testable import Mahu

@MainActor
final class LiveSleepWakeObservationRegistrarTests: XCTestCase {
    func testWillSleepNotificationTriggersHandlerSynchronously() {
        let context = makeRegistrarContext(
            willSleep: {},
            didWake: {}
        )
        defer { context.cancel() }

        context.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)

        XCTAssertEqual(context.willSleepCallCount(), 1)
        XCTAssertEqual(context.didWakeCallCount(), 0)
    }

    func testDidWakeNotificationTriggersHandlerSynchronously() {
        let context = makeRegistrarContext(willSleep: {}, didWake: {})
        defer { context.cancel() }

        context.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)

        XCTAssertEqual(context.willSleepCallCount(), 0)
        XCTAssertEqual(context.didWakeCallCount(), 1)
    }

    func testBackgroundPostedNotificationsSynchronouslyHopToMainActorBeforeReturning() async {
        let orderLock = NSLock()
        var eventOrder: [String] = []
        let context = makeRegistrarContext(
            willSleep: {
                orderLock.lock()
                eventOrder.append("handler")
                orderLock.unlock()
            },
            didWake: {}
        )
        defer { context.cancel() }

        let completion = expectation(description: "background post completed")

        DispatchQueue.global(qos: .userInitiated).async {
            context.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
            orderLock.lock()
            eventOrder.append("post-returned")
            orderLock.unlock()
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 1.0)

        orderLock.lock()
        defer { orderLock.unlock() }
        XCTAssertEqual(eventOrder, ["handler", "post-returned"])
        XCTAssertEqual(context.willSleepCallCount(), 1)
        XCTAssertEqual(context.didWakeCallCount(), 0)
    }

    func testCancelIsIdempotentAndStopsFutureEvents() async {
        let unexpectedSleepOrWake = expectation(description: "sleep wake should stay cancelled")
        unexpectedSleepOrWake.isInverted = true
        let context = makeRegistrarContext(
            willSleep: {
                unexpectedSleepOrWake.fulfill()
            },
            didWake: {
                unexpectedSleepOrWake.fulfill()
            }
        )

        context.cancel()
        context.cancel()
        context.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        context.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)

        await fulfillment(of: [unexpectedSleepOrWake], timeout: 0.1)
        XCTAssertEqual(context.willSleepCallCount(), 0)
        XCTAssertEqual(context.didWakeCallCount(), 0)
    }

    private func makeRegistrarContext(
        willSleep: @escaping @MainActor () -> Void = {},
        didWake: @escaping @MainActor () -> Void = {}
    ) -> (
        notificationCenter: NotificationCenter,
        willSleepCallCount: () -> Int,
        didWakeCallCount: () -> Int,
        cancel: SleepWakeObservationCancellation
    ) {
        let notificationCenter = NotificationCenter()
        var willSleepCallCount = 0
        var didWakeCallCount = 0

        let cancel = LiveSleepWakeObservationRegistrar.make(
            willSleep: {
                willSleepCallCount += 1
                willSleep()
            },
            didWake: {
                didWakeCallCount += 1
                didWake()
            },
            workspaceNotificationCenter: notificationCenter
        )

        return (
            notificationCenter,
            { willSleepCallCount },
            { didWakeCallCount },
            cancel
        )
    }
}
