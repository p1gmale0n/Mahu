import Foundation
import XCTest
@testable import Mahu

@MainActor
final class LiveScreenLockObservationRegistrarTests: XCTestCase {
    func testScreenLockedNotificationTriggersHandlerSynchronously() {
        let context = makeRegistrarContext(didLockScreen: {}, didUnlockScreen: {})
        defer { context.cancel() }

        context.notificationCenter.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)

        XCTAssertEqual(context.didLockScreenCallCount(), 1)
        XCTAssertEqual(context.didUnlockScreenCallCount(), 0)
    }

    func testScreenUnlockedNotificationTriggersHandlerSynchronously() {
        let context = makeRegistrarContext(didLockScreen: {}, didUnlockScreen: {})
        defer { context.cancel() }

        context.notificationCenter.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        XCTAssertEqual(context.didLockScreenCallCount(), 0)
        XCTAssertEqual(context.didUnlockScreenCallCount(), 1)
    }

    func testBackgroundPostedNotificationsSynchronouslyHopToMainActorBeforeReturning() async {
        let orderQueue = DispatchQueue(label: "LiveScreenLockObservationRegistrarTests.eventOrder")
        var eventOrder: [String] = []
        let context = makeRegistrarContext(
            didLockScreen: {
                orderQueue.sync {
                    eventOrder.append("handler")
                }
            },
            didUnlockScreen: {}
        )
        defer { context.cancel() }

        let completion = expectation(description: "background post completed")

        DispatchQueue.global(qos: .userInitiated).async {
            context.notificationCenter.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
            orderQueue.sync {
                eventOrder.append("post-returned")
            }
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 1.0)

        let recordedOrder = orderQueue.sync { eventOrder }
        XCTAssertEqual(recordedOrder, ["handler", "post-returned"])
        XCTAssertEqual(context.didLockScreenCallCount(), 1)
        XCTAssertEqual(context.didUnlockScreenCallCount(), 0)
    }

    func testCancelIsIdempotentAndStopsFutureEvents() async {
        let unexpectedScreenLockChange = expectation(description: "screen lock observation should stay cancelled")
        unexpectedScreenLockChange.isInverted = true
        let context = makeRegistrarContext(
            didLockScreen: {
                unexpectedScreenLockChange.fulfill()
            },
            didUnlockScreen: {
                unexpectedScreenLockChange.fulfill()
            }
        )

        context.cancel()
        context.cancel()
        context.notificationCenter.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        context.notificationCenter.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        await fulfillment(of: [unexpectedScreenLockChange], timeout: 0.1)
        XCTAssertEqual(context.didLockScreenCallCount(), 0)
        XCTAssertEqual(context.didUnlockScreenCallCount(), 0)
    }

    func testProductionFactoryUsesProvidedDistributedNotificationCenterFactory() {
        let notificationCenter = NotificationCenter()
        var providerCallCount = 0
        var didLockScreenCallCount = 0
        var didUnlockScreenCallCount = 0
        let cancel = LiveScreenLockObservationRegistrar.make(
            didLockScreen: {
                didLockScreenCallCount += 1
            },
            didUnlockScreen: {
                didUnlockScreenCallCount += 1
            },
            distributedNotificationCenterProvider: {
                providerCallCount += 1
                return notificationCenter
            }
        )
        defer { cancel() }

        notificationCenter.post(name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        notificationCenter.post(name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        XCTAssertEqual(providerCallCount, 1)
        XCTAssertEqual(didLockScreenCallCount, 1)
        XCTAssertEqual(didUnlockScreenCallCount, 1)
    }

    private func makeRegistrarContext(
        didLockScreen: @escaping @MainActor () -> Void = {},
        didUnlockScreen: @escaping @MainActor () -> Void = {}
    ) -> (
        notificationCenter: NotificationCenter,
        didLockScreenCallCount: () -> Int,
        didUnlockScreenCallCount: () -> Int,
        cancel: ScreenLockObservationCancellation
    ) {
        let notificationCenter = NotificationCenter()
        var didLockScreenCallCount = 0
        var didUnlockScreenCallCount = 0

        let cancel = LiveScreenLockObservationRegistrar.make(
            didLockScreen: {
                didLockScreenCallCount += 1
                didLockScreen()
            },
            didUnlockScreen: {
                didUnlockScreenCallCount += 1
                didUnlockScreen()
            },
            distributedNotificationCenter: notificationCenter
        )

        return (
            notificationCenter,
            { didLockScreenCallCount },
            { didUnlockScreenCallCount },
            cancel
        )
    }
}
