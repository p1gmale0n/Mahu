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

    func testRuntimeDetectionRecognizesXCTestMarkers() {
        XCTAssertTrue(AppRuntime.isRunningTests(environment: [
            "XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration",
        ]))
        XCTAssertFalse(AppRuntime.isRunningTests(environment: [:]))
    }
}
