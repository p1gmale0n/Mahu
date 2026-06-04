import AppKit
import XCTest
@testable import Mahu

@MainActor
final class BreakOverlayFocusRetentionTests: XCTestCase {
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

        let didShowBreak = manager.showBreak(remainingSeconds: 20)
        manager.hideBreak()
        focusObserver.fireAll()

        XCTAssertFalse(didShowBreak)
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
}
