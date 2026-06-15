import XCTest
@testable import Mahu

@MainActor
final class SettingsLegacyDisplayMappingTests: XCTestCase {
    func testFractionalTimerValuesMapToNearestSupportedDisplayValues() {
        let startupConfig = AppConfig(
            workDurationSeconds: 89.1,
            breakDurationSeconds: 32.4,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 89.1,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Fractional",
            launchAtLoginEnabled: false
        )
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: startupConfig),
            saveConfig: { _ in true }
        )

        XCTAssertEqual(viewModel.workDurationMinutes, 1)
        XCTAssertEqual(viewModel.breakDurationSeconds, 30)
        XCTAssertEqual(viewModel.idleAwayResetMinutes, 1)
        XCTAssertNotNil(viewModel.supportedValueNormalizationNoticeText)
    }

    func testFractionalBreakDurationRoundsUpOnlyAfterCrossingNearestStepMidpoint() {
        let startupConfig = AppConfig(
            workDurationSeconds: 1_200,
            breakDurationSeconds: 32.6,
            idleAwayResetEnabled: false,
            idleAwayResetThresholdSeconds: AppConfig.defaultIdleAwayResetThresholdSeconds,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Fractional",
            launchAtLoginEnabled: false
        )
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: startupConfig),
            saveConfig: { _ in true }
        )

        XCTAssertEqual(viewModel.breakDurationSeconds, 35)
        XCTAssertNotNil(viewModel.supportedValueNormalizationNoticeText)
    }
}
