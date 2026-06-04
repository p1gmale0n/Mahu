import AppKit
import XCTest
@testable import Mahu

final class SmokeTests: XCTestCase {
    func testSmokeInstantiatesDefaultTimerState() {
        let timer = BreakTimer()

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: AppConfig.default.workDurationSeconds))
    }

    func testHostedAppBundleContainsDecodableBackgroundImageResource() throws {
        let resourceURL = try XCTUnwrap(Bundle.main.url(forResource: "background", withExtension: "png"))
        let image = try XCTUnwrap(NSImage(contentsOf: resourceURL))

        XCTAssertEqual(resourceURL.lastPathComponent, "background.png")
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testHostedAppBundleBackgroundImageLivesInsideBundleResources() throws {
        let resourceURL = try XCTUnwrap(Bundle.main.url(forResource: "background", withExtension: "png"))
        let bundleURL = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let resolvedResourceURL = resourceURL.resolvingSymlinksInPath()

        XCTAssertTrue(resolvedResourceURL.path.hasPrefix(bundleURL.path + "/"))
    }

    func testHostedAppBundleEnablesMenuBarOnlyMode() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool, true)
    }

    func testRuntimeDetectionRecognizesXCTestMarkers() {
        XCTAssertTrue(AppRuntime.isRunningTests(environment: [
            "XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration",
        ]))
        XCTAssertFalse(AppRuntime.isRunningTests(environment: [:]))
        XCTAssertFalse(AppRuntime.shouldStartProductionCoordinator(environment: [
            AppRuntime.disableCoordinatorStartupEnvironmentKey: "1",
        ]))
        XCTAssertFalse(AppRuntime.shouldStartProductionCoordinator(environment: [
            "XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration",
        ]))
        XCTAssertTrue(AppRuntime.shouldStartProductionCoordinator(environment: [:]))
    }

    @MainActor
    func testAppDelegateSkipsCoordinatorStartupWhenExplicitlyDisabled() {
        var startCallCount = 0
        let appDelegate = AppDelegate()
        appDelegate.environmentProvider = {
            [AppRuntime.disableCoordinatorStartupEnvironmentKey: "1"]
        }
        appDelegate.coordinatorStarter = {
            startCallCount += 1
            return NSObject()
        }

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertEqual(startCallCount, 0)
    }

    @MainActor
    func testAppDelegateStartsCoordinatorWhenStartupIsAllowed() {
        var startCallCount = 0
        let appDelegate = AppDelegate()
        appDelegate.environmentProvider = { [:] }
        appDelegate.coordinatorStarter = {
            startCallCount += 1
            return NSObject()
        }

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertEqual(startCallCount, 1)
    }

    @MainActor
    func testLiveRepeatingSchedulerFiresAndCancelsOnMainRunLoop() {
        let didFireTwice = expectation(description: "timer fires twice")
        didFireTwice.expectedFulfillmentCount = 2
        var fireCount = 0

        let cancel = LiveRepeatingScheduler.schedule(interval: 0.01) {
            fireCount += 1
            if fireCount <= 2 {
                didFireTwice.fulfill()
            }
        }

        wait(for: [didFireTwice], timeout: 1)
        cancel()

        let fireCountAfterCancellation = fireCount
        let didDrainRunLoop = expectation(description: "run loop drains after cancellation")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            didDrainRunLoop.fulfill()
        }

        wait(for: [didDrainRunLoop], timeout: 1)
        XCTAssertEqual(fireCount, fireCountAfterCancellation)
    }
}
