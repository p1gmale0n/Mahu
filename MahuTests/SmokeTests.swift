import XCTest
@testable import Mahu

final class SmokeTests: XCTestCase {
    func testSmokeInstantiatesDefaultTimerState() {
        let timer = BreakTimer()

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: AppConfig.default.workDurationSeconds))
    }

    func testRuntimeDetectionRecognizesXCTestMarkers() {
        XCTAssertTrue(AppRuntime.isRunningTests(environment: [
            "XCTestConfigurationFilePath": "/tmp/session.xctestconfiguration",
        ]))
        XCTAssertFalse(AppRuntime.isRunningTests(environment: [:]))
    }
}
