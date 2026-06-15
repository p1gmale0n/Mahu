import XCTest
@testable import Mahu

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testInitialMappingUsesDesignUnits() {
        let config = AppConfig(
            workDurationSeconds: 1_200,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 300,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Look away now",
            launchAtLoginEnabled: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: config)

        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertEqual(viewModel.workDurationMinutes, 20)
        XCTAssertEqual(viewModel.breakDurationSeconds, 20)
        XCTAssertTrue(viewModel.idleAwayResetEnabled)
        XCTAssertEqual(viewModel.idleAwayResetMinutes, 5)
        XCTAssertTrue(viewModel.showMenuTimer)
        XCTAssertTrue(viewModel.launchAtLoginEnabled)
        XCTAssertEqual(viewModel.breakOverlayMessageText, "Look away now")
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "Look away now")
        XCTAssertEqual(viewModel.workDurationDisplayText, "20 min")
        XCTAssertEqual(viewModel.breakDurationDisplayText, "20 sec")
        XCTAssertEqual(viewModel.idleAwayResetDisplayText, "5 min")
        XCTAssertTrue(viewModel.isIdleAwayThresholdEditable)
        XCTAssertNil(viewModel.saveFailureMessage)
    }

    func testViewFacingFooterTextMatchesSettingsUIContract() {
        let viewModel = makeViewModel(runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default))

        XCTAssertEqual(
            viewModel.launchAtLoginFooterText,
            "This row reflects the current Launch at Login desired state from config/runtime. Change it through config.json or signing-supported Login Item flows; the Settings toggle is read-only."
        )
        XCTAssertEqual(
            viewModel.awayBehaviorFooterText,
            "Mahu always resets the timer when your screen is locked or your Mac goes to sleep."
        )
    }

    func testValidUpdatesApplyRuntimeSettingsBeforeSave() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        var savedConfigs: [AppConfig] = []
        var runtimeSettingsSeenBySaver: [AppConfig] = []
        let expectedConfig = AppConfig(
            workDurationSeconds: 2_700,
            breakDurationSeconds: 35,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 420,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "New message",
            launchAtLoginEnabled: false
        )
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore) { config in
            runtimeSettingsSeenBySaver.append(runtimeSettingsStore.currentSettings)
            savedConfigs.append(config)
            return true
        }

        viewModel.updateWorkDurationMinutes(45)
        viewModel.updateBreakDurationSeconds(31)
        viewModel.updateIdleAwayResetEnabled(true)
        viewModel.updateIdleAwayResetMinutes(7)
        viewModel.updateShowMenuTimer(true)
        viewModel.updateBreakOverlayMessageText("New message")

        XCTAssertEqual(runtimeSettingsStore.currentSettings, expectedConfig)
        XCTAssertEqual(runtimeSettingsStore.updates.last, expectedConfig)
        XCTAssertEqual(savedConfigs.last, expectedConfig)
        XCTAssertEqual(runtimeSettingsSeenBySaver.last, expectedConfig)
        XCTAssertNil(viewModel.saveFailureMessage)
    }

    func testEmptyOverlayMessageNormalizesToDefaultMessage() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        viewModel.updateBreakOverlayMessageText(" \n\t ")

        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testDuplicateUpdatesAreNoOps() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        var saveCallCount = 0
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore) { _ in
            saveCallCount += 1
            return true
        }

        viewModel.updateWorkDurationMinutes(20)
        viewModel.updateBreakDurationSeconds(20)
        viewModel.updateIdleAwayResetEnabled(false)
        viewModel.updateIdleAwayResetMinutes(5)
        viewModel.updateShowMenuTimer(false)
        viewModel.updateBreakOverlayMessageText(AppConfig.defaultBreakOverlayMessageText)

        XCTAssertTrue(runtimeSettingsStore.updates.isEmpty)
        XCTAssertEqual(saveCallCount, 0)
        XCTAssertNil(viewModel.saveFailureMessage)
        XCTAssertFalse(viewModel.isIdleAwayThresholdEditable)
    }

    func testSaveFailureKeepsRuntimeSettingsAndExposesWarning() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore) { _ in false }

        viewModel.updateShowMenuTimer(true)

        XCTAssertTrue(runtimeSettingsStore.currentSettings.showStatusItemTimerState)
        XCTAssertEqual(
            viewModel.saveFailureMessage,
            "Couldn't save settings to config.json. Mahu keeps the current in-app settings active, but system-integrated changes may already have taken effect."
        )
        XCTAssertEqual(
            viewModel.saveWarningText,
            "Couldn't save settings to config.json. Mahu keeps the current in-app settings active, but system-integrated changes may already have taken effect."
        )
        XCTAssertTrue(viewModel.hasSaveFailure)
    }

    func testRejectedRuntimeUpdateSkipsSaveAndRestoresPublishedState() {
        let runtimeSettingsStore = RejectingRuntimeSettingsStore(currentSettings: .default)
        var saveCallCount = 0
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore) { _ in
            saveCallCount += 1
            return true
        }

        viewModel.updateShowMenuTimer(true)

        XCTAssertFalse(runtimeSettingsStore.currentSettings.showStatusItemTimerState)
        XCTAssertFalse(viewModel.showMenuTimer)
        XCTAssertEqual(saveCallCount, 0)
        XCTAssertNil(viewModel.saveFailureMessage)
    }

    func testSuccessfulSaveClearsPreviousWarning() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        var saveResults = [false, true]
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore) { _ in
            saveResults.removeFirst()
        }

        viewModel.updateShowMenuTimer(true)
        XCTAssertEqual(
            viewModel.saveFailureMessage,
            "Couldn't save settings to config.json. Mahu keeps the current in-app settings active, but system-integrated changes may already have taken effect."
        )

        viewModel.updateShowMenuTimer(false)

        XCTAssertNil(viewModel.saveFailureMessage)
    }

    func testSettingsPersistenceRunsBeforeUpdateReturns() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        var didSave = false
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in
                didSave = true
                return true
            }
        )

        viewModel.updateShowMenuTimer(true)

        XCTAssertTrue(didSave)
    }

    func testUnsupportedValueNormalizationClampsLoadedValuesForDisplay() {
        let startupConfig = AppConfig(
            workDurationSeconds: 30,
            breakDurationSeconds: 601,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 14_500,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Clamped",
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertEqual(viewModel.workDurationMinutes, 1)
        XCTAssertEqual(viewModel.breakDurationSeconds, 600)
        XCTAssertEqual(viewModel.idleAwayResetMinutes, 240)
        XCTAssertEqual(
            viewModel.supportedValueNormalizationNoticeText,
            "Some timer values loaded from config.json are outside the Settings UI ranges. Mahu is showing the nearest supported values here, but the current runtime and config keep each raw value until you edit that specific control."
        )
    }

    func testUnsupportedValueNormalizationUsesNearestSupportedDisplayValues() {
        let startupConfig = AppConfig(
            workDurationSeconds: 61,
            breakDurationSeconds: 31,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 89,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Nearest",
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)

        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertEqual(viewModel.workDurationMinutes, 1)
        XCTAssertEqual(viewModel.breakDurationSeconds, 30)
        XCTAssertEqual(viewModel.idleAwayResetMinutes, 1)
        XCTAssertNotNil(viewModel.supportedValueNormalizationNoticeText)
    }

    func testHugeIdleAwayThresholdMapsSafelyIntoSupportedDisplayRange() {
        let startupConfig = AppConfig(
            workDurationSeconds: 1_200,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: .greatestFiniteMagnitude,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Huge threshold",
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)

        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertEqual(viewModel.idleAwayResetMinutes, 240)
        XCTAssertNotNil(viewModel.supportedValueNormalizationNoticeText)
    }

    func testUnrelatedUpdatePreservesLegacyValuesAndNormalizationNotice() {
        let startupConfig = AppConfig(
            workDurationSeconds: 30,
            breakDurationSeconds: 601,
            idleAwayResetEnabled: false,
            idleAwayResetThresholdSeconds: 14_500,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Legacy",
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertNotNil(viewModel.supportedValueNormalizationNoticeText)

        viewModel.updateShowMenuTimer(true)

        XCTAssertEqual(
            runtimeSettingsStore.currentSettings,
            AppConfig(
                workDurationSeconds: 30,
                breakDurationSeconds: 601,
                idleAwayResetEnabled: false,
                idleAwayResetThresholdSeconds: 14_500,
                showStatusItemTimerState: true,
                breakOverlayMessageText: "Legacy",
                launchAtLoginEnabled: false
            )
        )
        XCTAssertEqual(
            viewModel.supportedValueNormalizationNoticeText,
            "Some timer values loaded from config.json are outside the Settings UI ranges. Mahu is showing the nearest supported values here, but the current runtime and config keep each raw value until you edit that specific control."
        )
    }

    func testEditingSpecificControlCanonicalizesOnlyThatControl() {
        let startupConfig = AppConfig(
            workDurationSeconds: 30,
            breakDurationSeconds: 601,
            idleAwayResetEnabled: false,
            idleAwayResetThresholdSeconds: 14_500,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Legacy",
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        viewModel.updateWorkDurationMinutes(2)

        XCTAssertEqual(
            runtimeSettingsStore.currentSettings,
            AppConfig(
                workDurationSeconds: 120,
                breakDurationSeconds: 601,
                idleAwayResetEnabled: false,
                idleAwayResetThresholdSeconds: 14_500,
                showStatusItemTimerState: false,
                breakOverlayMessageText: "Legacy",
                launchAtLoginEnabled: false
            )
        )
        XCTAssertEqual(
            viewModel.supportedValueNormalizationNoticeText,
            "Some timer values loaded from config.json are outside the Settings UI ranges. Mahu is showing the nearest supported values here, but the current runtime and config keep each raw value until you edit that specific control."
        )
    }

    func testCommittingUnchangedBreakOverlayDraftPreservesNormalizationNotice() {
        let startupConfig = AppConfig(
            workDurationSeconds: 30,
            breakDurationSeconds: 601,
            idleAwayResetEnabled: false,
            idleAwayResetThresholdSeconds: 14_500,
            showStatusItemTimerState: false,
            breakOverlayMessageText: "Legacy",
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        viewModel.commitBreakOverlayMessageDraft()

        XCTAssertEqual(
            viewModel.supportedValueNormalizationNoticeText,
            "Some timer values loaded from config.json are outside the Settings UI ranges. Mahu is showing the nearest supported values here, but the current runtime and config keep each raw value until you edit that specific control."
        )
    }

    func testObservedRuntimeSettingsUpdatesRefreshPublishedStateAndUseLatestSettingsAsBase() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)
        let externallyAppliedSettings = AppConfig(
            workDurationSeconds: 1_800,
            breakDurationSeconds: 45,
            idleAwayResetEnabled: true,
            idleAwayResetThresholdSeconds: 600,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "External change",
            launchAtLoginEnabled: false
        )

        runtimeSettingsStore.update(externallyAppliedSettings)

        XCTAssertEqual(viewModel.workDurationMinutes, 30)
        XCTAssertEqual(viewModel.breakDurationSeconds, 45)
        XCTAssertTrue(viewModel.idleAwayResetEnabled)
        XCTAssertEqual(viewModel.idleAwayResetMinutes, 10)
        XCTAssertTrue(viewModel.showMenuTimer)
        XCTAssertEqual(viewModel.breakOverlayMessageText, "External change")
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "External change")

        viewModel.updateShowMenuTimer(false)

        XCTAssertEqual(
            runtimeSettingsStore.currentSettings,
            AppConfig(
                workDurationSeconds: 1_800,
                breakDurationSeconds: 45,
                idleAwayResetEnabled: true,
                idleAwayResetThresholdSeconds: 600,
                showStatusItemTimerState: false,
                breakOverlayMessageText: "External change",
                launchAtLoginEnabled: false
            )
        )
    }

    func testObservedRuntimeSettingsUpdateRefreshesLaunchAtLoginDisplayState() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertFalse(viewModel.launchAtLoginEnabled)

        runtimeSettingsStore.update(
            AppConfig(
                workDurationSeconds: 1_200,
                breakDurationSeconds: 20,
                idleAwayResetEnabled: false,
                idleAwayResetThresholdSeconds: 300,
                showStatusItemTimerState: false,
                breakOverlayMessageText: AppConfig.defaultBreakOverlayMessageText,
                launchAtLoginEnabled: true
            )
        )

        XCTAssertTrue(viewModel.launchAtLoginEnabled)
    }

    func testOversizedSettingsDraftKeepsPreviousSavedMessageActive() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        var saveCallCount = 0
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in
                saveCallCount += 1
                return true
            },
            canPersistConfig: { config in
                config.breakOverlayMessageText.utf8.count <= 32
            }
        )

        viewModel.updateBreakOverlayMessageDraft(String(repeating: "x", count: 64))
        viewModel.commitBreakOverlayMessageDraft()

        XCTAssertEqual(saveCallCount, 0)
        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, String(repeating: "x", count: 64))
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(
            viewModel.saveFailureMessage,
            "This Settings value is too large to save to config.json. Mahu keeps the previous saved value active until you reduce it."
        )
        XCTAssertTrue(viewModel.hasSaveFailure)
    }

    private func makeViewModel(
        runtimeSettingsStore: RuntimeSettingsStoring,
        saveConfig: @escaping SettingsViewModel.ConfigSaver = { _ in true }
    ) -> SettingsViewModel {
        SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: saveConfig
        )
    }
}

@MainActor
private final class RejectingRuntimeSettingsStore: RuntimeSettingsStoring {
    private(set) var currentSettings: AppConfig

    init(currentSettings: AppConfig) {
        self.currentSettings = currentSettings
    }

    @discardableResult
    func addObserver(_ observer: @escaping (AppConfig) -> Void) -> () -> Void {
        {}
    }

    func update(_ newSettings: AppConfig) {
    }
}
