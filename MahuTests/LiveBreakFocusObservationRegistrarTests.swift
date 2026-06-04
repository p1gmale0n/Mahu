import AppKit
import XCTest
@testable import Mahu

@MainActor
final class LiveBreakFocusObservationRegistrarTests: XCTestCase {
    private enum TestNotificationKey {
        static let processIdentifier = "processIdentifier"
    }

    func testIgnoresOwnProcessActivation() async {
        let context = makeRegistrarContext()
        defer { context.cancel() }

        context.workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [TestNotificationKey.processIdentifier: Int32(101)]
        )
        await Task.yield()

        XCTAssertEqual(context.handlerCallCount(), 0)
    }

    func testDidResignActiveNotificationTriggersHandler() async {
        let handledFocusLoss = expectation(description: "resign active handled")
        let context = makeRegistrarContext {
            handledFocusLoss.fulfill()
        }
        defer { context.cancel() }

        context.applicationNotificationCenter.post(
            name: NSApplication.didResignActiveNotification,
            object: context.applicationObject
        )

        await fulfillment(of: [handledFocusLoss], timeout: 1.0)
        XCTAssertEqual(context.handlerCallCount(), 1)
    }

    func testForeignWorkspaceActivationNotificationTriggersHandler() async {
        let handledFocusLoss = expectation(description: "workspace activation handled")
        let context = makeRegistrarContext {
            handledFocusLoss.fulfill()
        }
        defer { context.cancel() }

        context.workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [TestNotificationKey.processIdentifier: Int32(202)]
        )

        await fulfillment(of: [handledFocusLoss], timeout: 1.0)
        XCTAssertEqual(context.handlerCallCount(), 1)
    }

    func testCoalescesResignAndWorkspaceSignalsIntoSingleHandlerCall() async {
        let handledFocusLoss = expectation(description: "focus loss handled once")
        let context = makeRegistrarContext {
            handledFocusLoss.fulfill()
        }
        defer { context.cancel() }

        context.applicationNotificationCenter.post(
            name: NSApplication.didResignActiveNotification,
            object: context.applicationObject
        )
        context.workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [TestNotificationKey.processIdentifier: Int32(202)]
        )

        await fulfillment(of: [handledFocusLoss], timeout: 1.0)
        XCTAssertEqual(context.handlerCallCount(), 1)
    }

    func testHandlesSeparateFocusLossBurstsIndependently() async {
        let firstFocusLoss = expectation(description: "first focus loss handled")
        let secondFocusLoss = expectation(description: "second focus loss handled")
        var handlerCallCount = 0
        let context = makeRegistrarContext {
            handlerCallCount += 1
            if handlerCallCount == 1 {
                firstFocusLoss.fulfill()
            } else if handlerCallCount == 2 {
                secondFocusLoss.fulfill()
            }
        }
        defer { context.cancel() }

        context.applicationNotificationCenter.post(
            name: NSApplication.didResignActiveNotification,
            object: context.applicationObject
        )
        await fulfillment(of: [firstFocusLoss], timeout: 1.0)

        context.workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [TestNotificationKey.processIdentifier: Int32(202)]
        )
        await fulfillment(of: [secondFocusLoss], timeout: 1.0)

        XCTAssertEqual(context.handlerCallCount(), 2)
    }

    func testCancelIsIdempotentAndStopsFutureEvents() async {
        let unexpectedFocusLoss = expectation(description: "focus loss should stay cancelled")
        unexpectedFocusLoss.isInverted = true
        let context = makeRegistrarContext {
            unexpectedFocusLoss.fulfill()
        }

        context.cancel()
        context.cancel()
        context.applicationNotificationCenter.post(
            name: NSApplication.didResignActiveNotification,
            object: context.applicationObject
        )
        context.workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [TestNotificationKey.processIdentifier: Int32(202)]
        )
        await fulfillment(of: [unexpectedFocusLoss], timeout: 0.1)

        XCTAssertEqual(context.handlerCallCount(), 0)
    }

    func testCancelSuppressesAlreadyQueuedFocusLossDelivery() async {
        let unexpectedFocusLoss = expectation(description: "queued focus loss should be cancelled")
        unexpectedFocusLoss.isInverted = true
        let context = makeRegistrarContext {
            unexpectedFocusLoss.fulfill()
        }

        context.applicationNotificationCenter.post(
            name: NSApplication.didResignActiveNotification,
            object: context.applicationObject
        )
        context.cancel()
        await Task.yield()
        await fulfillment(of: [unexpectedFocusLoss], timeout: 0.1)

        XCTAssertEqual(context.handlerCallCount(), 0)
    }

    private func makeRegistrarContext(
        onFocusLoss: @escaping () -> Void = {}
    ) -> (
        applicationNotificationCenter: NotificationCenter,
        workspaceNotificationCenter: NotificationCenter,
        applicationObject: NSObject,
        handlerCallCount: () -> Int,
        cancel: BreakFocusObservationCancellation
    ) {
        let applicationNotificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        let applicationObject = NSObject()
        var handlerCallCount = 0

        let cancel = LiveBreakFocusObservationRegistrar.make(
            handler: {
                handlerCallCount += 1
                onFocusLoss()
            },
            applicationNotificationCenter: applicationNotificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter,
            applicationObject: applicationObject,
            currentProcessIdentifier: 101,
            activatedProcessIdentifierResolver: { notification in
                notification.userInfo?[TestNotificationKey.processIdentifier] as? Int32
            }
        )

        return (
            applicationNotificationCenter,
            workspaceNotificationCenter,
            applicationObject,
            { handlerCallCount },
            cancel
        )
    }
}
