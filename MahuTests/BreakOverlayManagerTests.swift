import XCTest
@testable import Mahu

@MainActor
final class BreakOverlayManagerTests: XCTestCase {
    func testShowBreakCreatesOneWindowPerDisplayAndActivatesApp() {
        let displays = [
            DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            DisplayDescriptor(frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        ]
        let windowBuilder = FakeOverlayWindowBuilder()
        var activationCount = 0

        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)

        XCTAssertEqual(windowBuilder.createdDisplays, displays)
        XCTAssertEqual(windowBuilder.windows.count, displays.count)
        XCTAssertEqual(windowBuilder.windows.map(\.showCallCount), [1, 1])
        XCTAssertEqual(activationCount, 1)
    }

    func testHideBreakClosesAndReleasesWindows() {
        let displays = [
            DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            DisplayDescriptor(frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        ]
        let windowBuilder = FakeOverlayWindowBuilder()
        var restoreCallCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            previousAppCapture: {
                PreviousFrontmostApplication {
                    restoreCallCount += 1
                }
            },
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        manager.hideBreak()

        XCTAssertNil(manager.viewModel)
        XCTAssertEqual(windowBuilder.windows.count, displays.count)
        XCTAssertEqual(windowBuilder.windows.map(\.closeCallCount), [1, 1])
        XCTAssertEqual(restoreCallCount, 1)
    }

    func testShowBreakWithoutDisplaysReturnsFalseAndSkipsScreenObservation() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: { [] },
            windowBuilder: windowBuilder,
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )

        let didShowBreak = manager.showBreak(remainingSeconds: 20)
        screenObserver.fireAll()

        XCTAssertFalse(didShowBreak)
        XCTAssertEqual(screenObserver.registrationCount, 0)
        XCTAssertEqual(screenObserver.handledEventCount, 0)
        XCTAssertTrue(windowBuilder.windows.isEmpty)
        XCTAssertNil(manager.viewModel)
    }

    func testUpdateRemainingSecondsRefreshesSharedViewModel() {
        let windowBuilder = FakeOverlayWindowBuilder()
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
            windowBuilder: windowBuilder,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        manager.updateRemainingSeconds(5)

        XCTAssertEqual(manager.viewModel?.countdownText, "00:05")
        XCTAssertEqual(windowBuilder.createdViewModels.first?.countdownText, "00:05")
    }

    func testSkipClosesWindowsAndForwardsCallback() {
        let displays = [
            DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
            DisplayDescriptor(frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080))
        ]
        let windowBuilder = FakeOverlayWindowBuilder()
        var restoreCallCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            previousAppCapture: {
                PreviousFrontmostApplication {
                    restoreCallCount += 1
                }
            },
            appActivator: {}
        )
        var didSkip = false

        manager.showBreak(remainingSeconds: 20) {
            didSkip = true
        }
        manager.viewModel?.skip()

        XCTAssertTrue(didSkip)
        XCTAssertNil(manager.viewModel)
        XCTAssertEqual(windowBuilder.windows.count, displays.count)
        XCTAssertEqual(windowBuilder.windows.map(\.closeCallCount), [1, 1])
        XCTAssertEqual(restoreCallCount, 1)
    }

    func testScreenChangeAddsDisplayDuringActiveBreak() {
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
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            screenObservationRegistrar: screenObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        let originalWindow = windowBuilder.windows[0]
        guard let sharedViewModel = try? XCTUnwrap(manager.viewModel) else {
            return XCTFail("Expected active break view model")
        }

        displays = [builtInDisplay, externalDisplay]
        screenObserver.fire()

        XCTAssertEqual(windowBuilder.createdDisplays, [builtInDisplay, externalDisplay])
        XCTAssertTrue(windowBuilder.createdViewModels.dropFirst().allSatisfy { $0 === sharedViewModel })
        XCTAssertEqual(originalWindow.showCallCount, 1)
        XCTAssertEqual(originalWindow.closeCallCount, 0)
        XCTAssertEqual(windowBuilder.windows.count, 2)
        XCTAssertEqual(windowBuilder.windows[1].showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[1].closeCallCount, 0)
        XCTAssertEqual(activationCount, 2)
    }

    func testScreenChangeRemovesDisplayDuringActiveBreak() {
        let builtInDisplay = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        let externalDisplay = DisplayDescriptor(
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            id: "external"
        )
        var displays = [builtInDisplay, externalDisplay]
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            screenObservationRegistrar: screenObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        let builtInWindow = windowBuilder.windows[0]
        let externalWindow = windowBuilder.windows[1]

        displays = [builtInDisplay]
        screenObserver.fire()

        XCTAssertEqual(windowBuilder.createdDisplays, [builtInDisplay, externalDisplay])
        XCTAssertEqual(builtInWindow.showCallCount, 1)
        XCTAssertEqual(builtInWindow.closeCallCount, 0)
        XCTAssertEqual(externalWindow.closeCallCount, 1)
        XCTAssertEqual(externalWindow.showCallCount, 1)
        XCTAssertEqual(activationCount, 2)
    }

    func testScreenChangeReplacesWindowWhenDisplayFrameChanges() {
        let initialDisplay = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        let resizedDisplay = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            id: "built-in"
        )
        var displays = [initialDisplay]
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            screenObservationRegistrar: screenObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        let originalWindow = windowBuilder.windows[0]
        guard let sharedViewModel = try? XCTUnwrap(manager.viewModel) else {
            return XCTFail("Expected active break view model")
        }

        displays = [resizedDisplay]
        screenObserver.fire()

        XCTAssertEqual(windowBuilder.createdDisplays, [initialDisplay, resizedDisplay])
        XCTAssertTrue(windowBuilder.createdViewModels.allSatisfy { $0 === sharedViewModel })
        XCTAssertEqual(originalWindow.closeCallCount, 1)
        XCTAssertEqual(windowBuilder.windows.count, 2)
        XCTAssertEqual(windowBuilder.windows[1].showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[1].closeCallCount, 0)
        XCTAssertEqual(activationCount, 2)
    }

    func testScreenChangeIgnoresEmptyDisplayResultsDuringActiveBreak() {
        let display = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        var displays = [display]
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            screenObservationRegistrar: screenObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        let originalViewModel = manager.viewModel
        let originalWindow = windowBuilder.windows[0]

        displays = []
        screenObserver.fire()

        XCTAssertTrue(manager.viewModel === originalViewModel)
        XCTAssertEqual(windowBuilder.createdDisplays, [display])
        XCTAssertEqual(windowBuilder.windows.count, 1)
        XCTAssertEqual(originalWindow.showCallCount, 1)
        XCTAssertEqual(originalWindow.closeCallCount, 0)
        XCTAssertEqual(screenObserver.cancelCount, 0)
        XCTAssertEqual(activationCount, 1)
    }
}
