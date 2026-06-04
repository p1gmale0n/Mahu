import XCTest
@testable import Mahu

@MainActor
final class BreakOverlayDisplayVisibilityTests: XCTestCase {
    func testScreenChangeTemporarilyRemovesAllDisplaysClosesWindowsAndReusesSharedBreakState() throws {
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
        let originalViewModel = try XCTUnwrap(manager.viewModel)
        let originalWindow = windowBuilder.windows[0]

        displays = []
        screenObserver.fire()

        XCTAssertTrue(manager.viewModel === originalViewModel)
        XCTAssertFalse(manager.hasVisibleOverlayWindows)
        XCTAssertEqual(originalWindow.showCallCount, 1)
        XCTAssertEqual(originalWindow.closeCallCount, 1)
        XCTAssertEqual(screenObserver.cancelCount, 0)
        XCTAssertEqual(activationCount, 1)

        displays = [display]
        screenObserver.fire()

        XCTAssertTrue(manager.viewModel === originalViewModel)
        XCTAssertTrue(manager.hasVisibleOverlayWindows)
        XCTAssertEqual(windowBuilder.createdDisplays, [display, display])
        XCTAssertTrue(windowBuilder.createdViewModels.allSatisfy { $0 === originalViewModel })
        XCTAssertEqual(windowBuilder.windows.count, 2)
        XCTAssertEqual(windowBuilder.windows[1].showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[1].closeCallCount, 0)
        XCTAssertEqual(activationCount, 2)
    }

    func testDisplayReturnAfterTemporaryNoDisplaysKeepsOriginalPreviousApplicationForRestore() {
        let display = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        var displays = [display]
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var restoreCallCount = 0
        var captureCallCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            previousAppCapture: {
                captureCallCount += 1
                return PreviousFrontmostApplication {
                    restoreCallCount += 1
                }
            },
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20)
        displays = []
        screenObserver.fire()
        displays = [display]
        screenObserver.fire()
        manager.hideBreak()

        XCTAssertEqual(captureCallCount, 1)
        XCTAssertEqual(restoreCallCount, 1)
    }

    func testVisibleOverlayCallbackTracksShowHideAndDisplayRecovery() {
        let display = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        var displays = [display]
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )
        var visibilityEvents: [Bool] = []
        manager.onVisibleOverlayWindowsChange = { isVisible in
            visibilityEvents.append(isVisible)
        }

        manager.showBreak(remainingSeconds: 20)
        displays = []
        screenObserver.fire()
        displays = [display]
        screenObserver.fire()
        manager.hideBreak()

        XCTAssertEqual(visibilityEvents, [true, false, true, false])
    }
}
