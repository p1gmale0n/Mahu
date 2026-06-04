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

    func testShowBreakCreatesViewModelWithProvidedMessageText() {
        let display = DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let windowBuilder = FakeOverlayWindowBuilder()
        let manager = BreakOverlayManager(
            screenProvider: { [display] },
            windowBuilder: windowBuilder,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20, messageText: "休憩しましょう — отдохни 🌿")

        XCTAssertEqual(manager.viewModel?.titleText, "休憩しましょう — отдохни 🌿")
        XCTAssertEqual(windowBuilder.createdViewModels.first?.titleText, "休憩しましょう — отдохни 🌿")
    }

    func testShowBreakNormalizesWhitespaceOnlyMessageTextToDefault() {
        let display = DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let windowBuilder = FakeOverlayWindowBuilder()
        let manager = BreakOverlayManager(
            screenProvider: { [display] },
            windowBuilder: windowBuilder,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20, messageText: "   \n\t  ")

        XCTAssertEqual(manager.viewModel?.titleText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(windowBuilder.createdViewModels.first?.titleText, AppConfig.defaultBreakOverlayMessageText)
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

    func testShowBreakWithoutDisplaysReturnsFalseButPreservesDormantSessionForDisplayRecovery() {
        let display = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        var displays: [DisplayDescriptor] = []
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var captureCallCount = 0
        var restoreCallCount = 0
        var activationCount = 0
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
            appActivator: { activationCount += 1 }
        )

        let didShowBreak = manager.showBreak(remainingSeconds: 20)

        XCTAssertFalse(didShowBreak)
        XCTAssertEqual(captureCallCount, 1)
        XCTAssertEqual(restoreCallCount, 0)
        XCTAssertEqual(screenObserver.registrationCount, 1)
        XCTAssertEqual(screenObserver.handledEventCount, 0)
        XCTAssertTrue(windowBuilder.windows.isEmpty)
        XCTAssertNotNil(manager.viewModel)
        XCTAssertTrue(manager.hasActiveBreakSession)
        XCTAssertFalse(manager.hasVisibleOverlayWindows)
        XCTAssertEqual(activationCount, 0)

        displays = [display]
        screenObserver.fire()

        XCTAssertEqual(screenObserver.handledEventCount, 1)
        XCTAssertTrue(manager.hasVisibleOverlayWindows)
        XCTAssertEqual(windowBuilder.createdDisplays, [display])
        XCTAssertEqual(windowBuilder.windows.count, 1)
        XCTAssertEqual(windowBuilder.windows[0].showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[0].closeCallCount, 0)
        XCTAssertEqual(activationCount, 1)

        manager.hideBreak()

        XCTAssertEqual(restoreCallCount, 1)
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

    func testScreenChangePreservesCustomMessageAndSharedBreakState() {
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
        var didSkip = false
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )

        manager.showBreak(remainingSeconds: 20, messageText: "休憩しましょう — отдохни 🌿") {
            didSkip = true
        }
        manager.updateRemainingSeconds(11)
        let originalWindow = windowBuilder.windows[0]
        guard let sharedViewModel = try? XCTUnwrap(manager.viewModel) else {
            return XCTFail("Expected active break view model")
        }

        displays = [builtInDisplay, externalDisplay]
        screenObserver.fire()
        manager.viewModel?.skip()

        XCTAssertEqual(windowBuilder.createdDisplays, [builtInDisplay, externalDisplay])
        XCTAssertTrue(windowBuilder.createdViewModels.allSatisfy { $0 === sharedViewModel })
        XCTAssertEqual(sharedViewModel.titleText, "休憩しましょう — отдохни 🌿")
        XCTAssertEqual(sharedViewModel.countdownText, "00:11")
        XCTAssertEqual(windowBuilder.windows.count, 2)
        XCTAssertEqual(originalWindow.closeCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[1].closeCallCount, 1)
        XCTAssertTrue(didSkip)
    }

    func testShowBreakResyncsDisplaysChangedBeforeScreenObserverRegistrationCompletes() {
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
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            focusObservationRegistrar: { _ in
                displays = [builtInDisplay, externalDisplay]
                return {}
            },
            screenObservationRegistrar: { _ in {} },
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)

        XCTAssertEqual(windowBuilder.createdDisplays, [builtInDisplay, externalDisplay])
        XCTAssertEqual(windowBuilder.windows.count, 2)
        XCTAssertEqual(windowBuilder.windows[0].showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[0].closeCallCount, 0)
        XCTAssertEqual(windowBuilder.windows[1].showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[1].closeCallCount, 0)
        XCTAssertTrue(windowBuilder.createdViewModels.allSatisfy { $0 === manager.viewModel })
        XCTAssertEqual(activationCount, 1)
    }

    func testShowBreakPreservesCapturedPreviousAppAcrossZeroWindowStartupRetry() {
        let builtInDisplay = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        var displays = [builtInDisplay]
        let windowBuilder = FakeOverlayWindowBuilder()
        var capturedPreviousApplicationCount = 0
        var shouldDropDisplaysDuringRegistration = true
        let manager = BreakOverlayManager(
            screenProvider: { displays },
            windowBuilder: windowBuilder,
            previousAppCapture: {
                capturedPreviousApplicationCount += 1
                return PreviousFrontmostApplication {}
            },
            focusObservationRegistrar: { _ in
                if shouldDropDisplaysDuringRegistration {
                    displays = []
                    shouldDropDisplaysDuringRegistration = false
                }
                return {}
            },
            screenObservationRegistrar: { _ in {} },
            appActivator: {}
        )

        XCTAssertFalse(manager.showBreak(remainingSeconds: 20))
        XCTAssertNotNil(manager.viewModel)
        XCTAssertEqual(capturedPreviousApplicationCount, 1)

        displays = [builtInDisplay]

        XCTAssertTrue(manager.showBreak(remainingSeconds: 20))
        XCTAssertEqual(capturedPreviousApplicationCount, 1)
        XCTAssertNotNil(manager.viewModel)
        XCTAssertEqual(windowBuilder.windows.count, 2)
        XCTAssertEqual(windowBuilder.windows[0].closeCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[1].showCallCount, 1)
        XCTAssertEqual(windowBuilder.windows[1].closeCallCount, 0)
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

    func testScreenChangeWithUnchangedDisplaysKeepsExistingWindowsWithoutReactivation() {
        let builtInDisplay = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        let externalDisplay = DisplayDescriptor(
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            id: "external"
        )
        let displays = [builtInDisplay, externalDisplay]
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
        let originalWindows = windowBuilder.windows

        screenObserver.fire()

        XCTAssertEqual(windowBuilder.createdDisplays, displays)
        XCTAssertEqual(windowBuilder.windows.count, 2)
        XCTAssertTrue(windowBuilder.windows[0] === originalWindows[0])
        XCTAssertTrue(windowBuilder.windows[1] === originalWindows[1])
        XCTAssertEqual(originalWindows.map(\.showCallCount), [1, 1])
        XCTAssertEqual(originalWindows.map(\.closeCallCount), [0, 0])
        XCTAssertEqual(activationCount, 1)
    }

    func testScreenChangeKeepsMirroredDisplaysWhenDisplayIdentifiersCollide() {
        let mirroredDisplays = [
            DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), id: "mirror"),
            DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), id: "mirror")
        ]
        let windowBuilder = FakeOverlayWindowBuilder()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var activationCount = 0
        let manager = BreakOverlayManager(
            screenProvider: { mirroredDisplays },
            windowBuilder: windowBuilder,
            screenObservationRegistrar: screenObserver.register,
            appActivator: { activationCount += 1 }
        )

        manager.showBreak(remainingSeconds: 20)
        let originalWindows = windowBuilder.windows

        screenObserver.fire()

        XCTAssertEqual(windowBuilder.createdDisplays, mirroredDisplays)
        XCTAssertEqual(windowBuilder.windows.count, 2)
        XCTAssertTrue(windowBuilder.windows[0] === originalWindows[0])
        XCTAssertTrue(windowBuilder.windows[1] === originalWindows[1])
        XCTAssertEqual(originalWindows.map(\.showCallCount), [1, 1])
        XCTAssertEqual(originalWindows.map(\.closeCallCount), [0, 0])
        XCTAssertEqual(activationCount, 1)
    }

    func testManagerDeinitCancelsObserversAndClosesWindowsWithoutRestoringPreviousApp() {
        let display = DisplayDescriptor(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            id: "built-in"
        )
        let windowBuilder = FakeOverlayWindowBuilder()
        let focusObserver = FakeBreakFocusObserverRegistrar()
        let screenObserver = FakeBreakScreenObserverRegistrar()
        var restoreCallCount = 0
        var manager: BreakOverlayManager? = BreakOverlayManager(
            screenProvider: { [display] },
            windowBuilder: windowBuilder,
            previousAppCapture: {
                PreviousFrontmostApplication {
                    restoreCallCount += 1
                }
            },
            focusObservationRegistrar: focusObserver.register,
            screenObservationRegistrar: screenObserver.register,
            appActivator: {}
        )

        manager?.showBreak(remainingSeconds: 20)
        let originalWindow = windowBuilder.windows[0]
        manager = nil

        XCTAssertEqual(focusObserver.cancelCount, 1)
        XCTAssertEqual(screenObserver.cancelCount, 1)
        XCTAssertEqual(originalWindow.closeCallCount, 1)
        XCTAssertEqual(restoreCallCount, 0)
    }
}
