import AppKit
import XCTest
@testable import Mahu

@MainActor
final class BreakOverlayFocusRetentionTests: XCTestCase {
    func testShowBreakRegistersFocusObserverWhenWindowsExist() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)

        XCTAssertEqual(focusObserver.registrationCount, 1)
        XCTAssertEqual(screenObserver.registrationCount, 1)
        XCTAssertNotNil(focusObserver.handler)
        XCTAssertNotNil(screenObserver.handler)
    }

    func testShowBreakWithoutDisplaysKeepsDormantSessionWithoutActivatingApp() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { [] },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            screenObservationRegistrar: screenObserver.register,
            appActivator: { activationCount += 1 }
        )

        let didShowBreak = manager.showBreak(remainingSeconds: 20)
        manager.hideBreak()
        focusObserver.fireAll()

        XCTAssertFalse(didShowBreak)
        XCTAssertEqual(focusObserver.registrationCount, 1)
        XCTAssertEqual(focusObserver.cancelCount, 1)
        XCTAssertEqual(screenObserver.registrationCount, 1)
        XCTAssertEqual(screenObserver.cancelCount, 1)
        XCTAssertEqual(focusObserver.handledEventCount, 0)
        XCTAssertEqual(screenObserver.handledEventCount, 0)
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
        let displays = [
            DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            DisplayDescriptor(frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        ]
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        focusObserver.fire()

        XCTAssertEqual(windowBuilder.windows.count, displays.count)
        XCTAssertEqual(windowBuilder.windows.map(\.showCallCount), [2, 2])
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

    func testScreenChangeKeepsOriginalPreviousApplicationForRestore() {
        let builtInDisplay = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        let externalDisplay = DisplayDescriptor(
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            id: "external"
        )
        var displays = [builtInDisplay]
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var restoreEvents: [String] = []
        var captureIndex = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            previousAppCapture: {
                captureIndex += 1
                let applicationName = "app-\(captureIndex)"
                return PreviousFrontmostApplication {
                    restoreEvents.append(applicationName)
                }
            },
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        displays = [builtInDisplay, externalDisplay]
        screenObserver.fire()
        manager.hideBreak()

        XCTAssertEqual(captureIndex, 1)
        XCTAssertEqual(restoreEvents, ["app-1"])
    }

    func testFocusLossAfterDisplayChangeReshowsAllCurrentOverlayWindows() {
        let builtInDisplay = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        let externalDisplay = DisplayDescriptor(
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            id: "external"
        )
        var displays = [builtInDisplay]
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            screenObservationRegistrar: screenObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        let originalWindow = windowBuilder.windows[0]

        displays = [builtInDisplay, externalDisplay]
        screenObserver.fire()
        let newWindow = windowBuilder.windows[1]
        focusObserver.fire()

        XCTAssertEqual(originalWindow.showCallCount, 2)
        XCTAssertEqual(newWindow.showCallCount, 2)
        XCTAssertEqual(focusObserver.handledEventCount, 1)
        XCTAssertEqual(activationCount, 3)
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

    func testHideBreakCancelsFocusAndScreenObservationBeforeLaterEvents() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        manager.hideBreak()
        focusObserver.fireAll()
        screenObserver.fireAll()

        XCTAssertEqual(focusObserver.registrationCount, 1)
        XCTAssertEqual(focusObserver.cancelCount, 1)
        XCTAssertEqual(focusObserver.handledEventCount, 0)
        XCTAssertEqual(screenObserver.registrationCount, 1)
        XCTAssertEqual(screenObserver.cancelCount, 1)
        XCTAssertEqual(screenObserver.handledEventCount, 0)
        XCTAssertEqual(windowBuilder.windows.first?.showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows.first?.closeCallCount, 1)
    }

    func testSkipCancelsFocusAndScreenObservationBeforeLaterEvents() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        manager.viewModel?.skip()
        focusObserver.fireAll()
        screenObserver.fireAll()

        XCTAssertEqual(focusObserver.registrationCount, 1)
        XCTAssertEqual(focusObserver.cancelCount, 1)
        XCTAssertEqual(focusObserver.handledEventCount, 0)
        XCTAssertEqual(screenObserver.registrationCount, 1)
        XCTAssertEqual(screenObserver.cancelCount, 1)
        XCTAssertEqual(screenObserver.handledEventCount, 0)
        XCTAssertEqual(windowBuilder.windows.first?.showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows.first?.closeCallCount, 1)
    }

    func testRepeatedShowBreakKeepsOnlyLatestFocusAndScreenObserversAndCancelsThemOnHide() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: focusObserver.register,
            screenObservationRegistrar: screenObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        let firstWindow = windowBuilder.windows[0]
        manager.showBreak(remainingSeconds: 20)
        let secondWindow = windowBuilder.windows[1]
        focusObserver.fireAll()
        screenObserver.fireAll()
        manager.hideBreak()
        focusObserver.fireAll()
        screenObserver.fireAll()

        XCTAssertEqual(focusObserver.registrationCount, 2)
        XCTAssertEqual(focusObserver.cancelCount, 2)
        XCTAssertEqual(focusObserver.handledEventCount, 1)
        XCTAssertEqual(screenObserver.registrationCount, 2)
        XCTAssertEqual(screenObserver.cancelCount, 2)
        XCTAssertEqual(screenObserver.handledEventCount, 1)
        XCTAssertEqual(firstWindow.closeCallCount, 1)
        XCTAssertEqual(firstWindow.showCallCount, 1)
        XCTAssertEqual(secondWindow.showCallCount, 2)
        XCTAssertEqual(secondWindow.closeCallCount, 1)
        XCTAssertEqual(activationCount, 3)
    }
}
