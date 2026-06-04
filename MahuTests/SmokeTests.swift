import AVFoundation
import AppKit
import XCTest
@testable import Mahu

final class SmokeTests: XCTestCase {
    private func hostedResourceURL(named name: String, extension ext: String) throws -> URL {
        try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: ext))
    }

    func testSmokeInstantiatesDefaultTimerState() {
        let timer = BreakTimer()

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: AppConfig.default.workDurationSeconds))
    }

    func testHostedAppBundleContainsDecodableBackgroundImageResource() throws {
        let resourceURL = try hostedResourceURL(named: "background", extension: "png")
        let image = try XCTUnwrap(NSImage(contentsOf: resourceURL))

        XCTAssertEqual(resourceURL.lastPathComponent, "background.png")
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testHostedAppBundleBackgroundImageLivesInsideBundleResources() throws {
        let resourceURL = try hostedResourceURL(named: "background", extension: "png")

        XCTAssertTrue(isHostedBundleResource(resourceURL))
    }

    func testHostedAppBundleContainsBreakCompletionSoundResource() throws {
        let resourceURL = try hostedResourceURL(named: "break-completion", extension: "caf")

        XCTAssertEqual(resourceURL.lastPathComponent, "break-completion.caf")
    }

    func testHostedAppBundleBreakCompletionSoundLivesInsideBundleResources() throws {
        let resourceURL = try hostedResourceURL(named: "break-completion", extension: "caf")

        XCTAssertTrue(isHostedBundleResource(resourceURL))
    }

    func testHostedAppBundleBreakCompletionSoundIsNonEmpty() throws {
        let resourceURL = try hostedResourceURL(named: "break-completion", extension: "caf")
        let fileSize = try XCTUnwrap(
            (try FileManager.default.attributesOfItem(atPath: resourceURL.path)[.size]) as? NSNumber
        )

        XCTAssertEqual(resourceURL.lastPathComponent, "break-completion.caf")
        XCTAssertGreaterThan(fileSize.intValue, 0)
    }

    func testHostedAppBundleBreakCompletionSoundCanBeDecodedByAVAudioPlayer() throws {
        let resourceURL = try hostedResourceURL(named: "break-completion", extension: "caf")
        let player = try AVAudioPlayer(contentsOf: resourceURL)

        XCTAssertTrue(player.prepareToPlay())
        XCTAssertGreaterThan(player.duration, 0)
    }

    func testHostedAppBundleDoesNotContainLegacyBreakCompletionSoundResource() {
        XCTAssertNil(Bundle.main.url(forResource: "sound", withExtension: "wav"))
    }

    func testHostedAppBundleContainsSystemBootTimePrivacyManifestReason() throws {
        let resourceURL = try hostedResourceURL(named: "PrivacyInfo", extension: "xcprivacy")
        let data = try Data(contentsOf: resourceURL)
        let plist = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let accessedAPITypes = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let systemBootTimeEntry = try XCTUnwrap(
            accessedAPITypes.first { entry in
                (entry["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategorySystemBootTime"
            }
        )
        let reasons = try XCTUnwrap(systemBootTimeEntry["NSPrivacyAccessedAPITypeReasons"] as? [String])

        XCTAssertTrue(isHostedBundleResource(resourceURL))
        XCTAssertEqual(reasons, ["35F9.1"])
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
        weak var coordinatorReference: NSObject?
        let appDelegate = AppDelegate()
        appDelegate.environmentProvider = { [:] }
        appDelegate.coordinatorStarter = {
            startCallCount += 1
            let coordinator = NSObject()
            coordinatorReference = coordinator
            return coordinator
        }

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )

        XCTAssertEqual(startCallCount, 1)
        XCTAssertNotNil(coordinatorReference)
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

    private func isHostedBundleResource(_ resourceURL: URL) -> Bool {
        let bundleURL = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let resolvedResourceURL = resourceURL.resolvingSymlinksInPath()

        return resolvedResourceURL.path.hasPrefix(bundleURL.path + "/")
    }
}
