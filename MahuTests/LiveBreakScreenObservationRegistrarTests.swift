import AppKit
import XCTest
@testable import Mahu

@MainActor
final class LiveBreakScreenObservationRegistrarTests: XCTestCase {
    func testScreenParametersNotificationTriggersHandler() async {
        let handledScreenChange = expectation(description: "screen change handled")
        let context = makeRegistrarContext {
            handledScreenChange.fulfill()
        }
        defer { context.cancel() }

        context.notificationCenter.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: context.applicationObject
        )

        await fulfillment(of: [handledScreenChange], timeout: 1.0)
        XCTAssertEqual(context.handlerCallCount(), 1)
    }

    func testCoalescesRepeatedScreenParametersNotifications() async {
        let handledScreenChange = expectation(description: "screen change handled once")
        let context = makeRegistrarContext {
            handledScreenChange.fulfill()
        }
        defer { context.cancel() }

        context.notificationCenter.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: context.applicationObject
        )
        context.notificationCenter.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: context.applicationObject
        )

        await fulfillment(of: [handledScreenChange], timeout: 1.0)
        XCTAssertEqual(context.handlerCallCount(), 1)
    }

    func testHandlesSeparateScreenChangeBurstsIndependently() async {
        let firstScreenChange = expectation(description: "first screen change handled")
        let secondScreenChange = expectation(description: "second screen change handled")
        var handlerCallCount = 0
        let context = makeRegistrarContext {
            handlerCallCount += 1
            if handlerCallCount == 1 {
                firstScreenChange.fulfill()
            } else if handlerCallCount == 2 {
                secondScreenChange.fulfill()
            }
        }
        defer { context.cancel() }

        context.notificationCenter.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: context.applicationObject
        )
        await fulfillment(of: [firstScreenChange], timeout: 1.0)

        context.notificationCenter.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: context.applicationObject
        )
        await fulfillment(of: [secondScreenChange], timeout: 1.0)

        XCTAssertEqual(context.handlerCallCount(), 2)
    }

    func testCancelIsIdempotentAndStopsFutureEvents() async {
        let unexpectedScreenChange = expectation(description: "screen change should stay cancelled")
        unexpectedScreenChange.isInverted = true
        let context = makeRegistrarContext {
            unexpectedScreenChange.fulfill()
        }

        context.cancel()
        context.cancel()
        context.notificationCenter.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: context.applicationObject
        )
        await fulfillment(of: [unexpectedScreenChange], timeout: 0.1)

        XCTAssertEqual(context.handlerCallCount(), 0)
    }

    func testCancelSuppressesAlreadyQueuedScreenChangeDelivery() async {
        let unexpectedScreenChange = expectation(description: "queued screen change should be cancelled")
        unexpectedScreenChange.isInverted = true
        let context = makeRegistrarContext {
            unexpectedScreenChange.fulfill()
        }

        context.notificationCenter.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: context.applicationObject
        )
        context.cancel()
        await Task.yield()
        await fulfillment(of: [unexpectedScreenChange], timeout: 0.1)

        XCTAssertEqual(context.handlerCallCount(), 0)
    }

    private func makeRegistrarContext(
        onScreenChange: @escaping () -> Void = {}
    ) -> (
        notificationCenter: NotificationCenter,
        applicationObject: NSObject,
        handlerCallCount: () -> Int,
        cancel: BreakScreenObservationCancellation
    ) {
        let notificationCenter = NotificationCenter()
        let applicationObject = NSObject()
        var handlerCallCount = 0

        let cancel = LiveBreakScreenObservationRegistrar.make(
            handler: {
                handlerCallCount += 1
                onScreenChange()
            },
            notificationCenter: notificationCenter,
            applicationObject: applicationObject
        )

        return (
            notificationCenter,
            applicationObject,
            { handlerCallCount },
            cancel
        )
    }
}
