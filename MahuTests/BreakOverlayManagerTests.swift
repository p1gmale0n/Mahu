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
        let windowBuilder = FakeOverlayWindowBuilder()
        var restoreCallCount = 0
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
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
        XCTAssertEqual(windowBuilder.windows.first?.closeCallCount, 1)
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
        let windowBuilder = FakeOverlayWindowBuilder()
        var restoreCallCount = 0
        let manager = BreakOverlayManager(
            screenProvider: {
                [DisplayDescriptor(frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
            },
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
        XCTAssertEqual(windowBuilder.windows.first?.closeCallCount, 1)
        XCTAssertEqual(restoreCallCount, 1)
    }
}
