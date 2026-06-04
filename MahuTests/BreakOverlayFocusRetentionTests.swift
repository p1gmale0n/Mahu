import AppKit
import XCTest
@testable import Mahu

@MainActor
final class BreakOverlayFocusRetentionTests: XCTestCase {
    private enum TestNotificationKey {
        static let processIdentifier = "processIdentifier"
    }

    func testShowBreakRegistersFocusObserverWhenWindowsExist() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)

        XCTAssertEqual(focusObserver.registrationCount, 1)
        XCTAssertNotNil(focusObserver.handler)
    }

    func testShowBreakWithoutDisplaysSkipsFocusObserverAndActivation() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { [] },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        manager.hideBreak()
        focusObserver.fireAll()

        XCTAssertEqual(focusObserver.registrationCount, 0)
        XCTAssertEqual(focusObserver.handledEventCount, 0)
        XCTAssertEqual(activationCount, 0)
        XCTAssertTrue(windowBuilder.windows.isEmpty)
        XCTAssertNil(manager.viewModel)
    }

    func testFocusObserverDoesNothingBeforeBreakIsShown() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            appActivator: {}
        )

        focusObserver.fire()

        XCTAssertEqual(focusObserver.registrationCount, 0)
        XCTAssertEqual(focusObserver.handledEventCount, 0)
        XCTAssertTrue(windowBuilder.windows.isEmpty)
        XCTAssertNil(manager.viewModel)
    }

    func testFocusLossReshowsExistingWindowsAndReactivatesApp() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        focusObserver.fire()

        XCTAssertEqual(windowBuilder.windows.count, 1)
        XCTAssertEqual(windowBuilder.windows.first?.showCallCount, 2)
        XCTAssertEqual(activationCount, 2)
        XCTAssertEqual(focusObserver.handledEventCount, 1)
    }

    func testFocusLossKeepsOriginalPreviousApplicationForRestore() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        var restoreEvents: [String] = []
        var captureIndex = 0
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            previousAppCapture: {
                captureIndex += 1
                let applicationName = "app-\(captureIndex)"
                return PreviousFrontmostApplication {
                    restoreEvents.append(applicationName)
                }
            },
            focusObservationRegistrar: focusObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        focusObserver.fire()
        manager.hideBreak()

        XCTAssertEqual(captureIndex, 1)
        XCTAssertEqual(restoreEvents, ["app-1"])
    }

    func testHideBreakCancelsFocusObservationBeforeLaterEvents() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        manager.hideBreak()
        focusObserver.fireAll()

        XCTAssertEqual(focusObserver.registrationCount, 1)
        XCTAssertEqual(focusObserver.cancelCount, 1)
        XCTAssertEqual(focusObserver.handledEventCount, 0)
        XCTAssertEqual(windowBuilder.windows.first?.showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows.first?.closeCallCount, 1)
    }

    func testSkipCancelsFocusObservationBeforeLaterEvents() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        manager.viewModel?.skip()
        focusObserver.fireAll()

        XCTAssertEqual(focusObserver.registrationCount, 1)
        XCTAssertEqual(focusObserver.cancelCount, 1)
        XCTAssertEqual(focusObserver.handledEventCount, 0)
        XCTAssertEqual(windowBuilder.windows.first?.showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows.first?.closeCallCount, 1)
    }

    func testRepeatedShowBreakKeepsOnlyLatestObserverAndCancelsItOnHide() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        let firstWindow = windowBuilder.windows[0]
        manager.showBreak(remainingSeconds: 20)
        let secondWindow = windowBuilder.windows[1]
        focusObserver.fireAll()
        manager.hideBreak()
        focusObserver.fireAll()

        XCTAssertEqual(focusObserver.registrationCount, 2)
        XCTAssertEqual(focusObserver.cancelCount, 2)
        XCTAssertEqual(focusObserver.handledEventCount, 1)
        XCTAssertEqual(firstWindow.closeCallCount, 1)
        XCTAssertEqual(firstWindow.showCallCount, 1)
        XCTAssertEqual(secondWindow.showCallCount, 2)
        XCTAssertEqual(secondWindow.closeCallCount, 1)
        XCTAssertEqual(activationCount, 3)
    }

    func testLiveFocusObservationRegistrarIgnoresOwnProcessActivation() async {
        let applicationNotificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        let applicationObject = NSObject()
        var handlerCallCount = 0

        let cancel = LiveBreakFocusObservationRegistrar.make(
            handler: { handlerCallCount += 1 },
            applicationNotificationCenter: applicationNotificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter,
            applicationObject: applicationObject,
            currentProcessIdentifier: 101,
            activatedProcessIdentifierResolver: { notification in
                notification.userInfo?[TestNotificationKey.processIdentifier] as? Int32
            }
        )

        workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [TestNotificationKey.processIdentifier: Int32(101)]
        )
        await Task.yield()

        XCTAssertEqual(handlerCallCount, 0)
        cancel()
    }

    func testLiveFocusObservationRegistrarCoalescesResignAndWorkspaceSignals() async {
        let applicationNotificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        let applicationObject = NSObject()
        var handlerCallCount = 0
        let handledFocusLoss = expectation(description: "focus loss handled once")

        let cancel = LiveBreakFocusObservationRegistrar.make(
            handler: {
                handlerCallCount += 1
                handledFocusLoss.fulfill()
            },
            applicationNotificationCenter: applicationNotificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter,
            applicationObject: applicationObject,
            currentProcessIdentifier: 101,
            activatedProcessIdentifierResolver: { notification in
                notification.userInfo?[TestNotificationKey.processIdentifier] as? Int32
            }
        )

        applicationNotificationCenter.post(
            name: NSApplication.didResignActiveNotification,
            object: applicationObject
        )
        workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [TestNotificationKey.processIdentifier: Int32(202)]
        )

        await fulfillment(of: [handledFocusLoss], timeout: 1.0)

        XCTAssertEqual(handlerCallCount, 1)
        cancel()
    }

    func testLiveFocusObservationRegistrarCancelIsIdempotentAndStopsFutureEvents() async {
        let applicationNotificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        let applicationObject = NSObject()
        var handlerCallCount = 0

        let cancel = LiveBreakFocusObservationRegistrar.make(
            handler: { handlerCallCount += 1 },
            applicationNotificationCenter: applicationNotificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter,
            applicationObject: applicationObject,
            currentProcessIdentifier: 101,
            activatedProcessIdentifierResolver: { notification in
                notification.userInfo?[TestNotificationKey.processIdentifier] as? Int32
            }
        )

        cancel()
        cancel()

        applicationNotificationCenter.post(
            name: NSApplication.didResignActiveNotification,
            object: applicationObject
        )
        workspaceNotificationCenter.post(
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            userInfo: [TestNotificationKey.processIdentifier: Int32(202)]
        )
        await Task.yield()

        XCTAssertEqual(handlerCallCount, 0)
    }
}
