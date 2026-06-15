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
        XCTAssertTrue(viewModel.showsIdleAwayResetStepper)
        XCTAssertNil(viewModel.saveFailureMessage)
    }

    func testViewFacingFooterTextMatchesSettingsUIContract() {
        let viewModel = makeViewModel(runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default))

        XCTAssertEqual(
            viewModel.launchAtLoginFooterText,
            "Mahu treats Launch at Login as a desired state. macOS may still require a signed app and Login Items approval before registration succeeds."
        )
        XCTAssertEqual(
            viewModel.awayBehaviorFooterText,
            "Mahu always resets the timer when your screen is locked or your Mac goes to sleep."
        )
        XCTAssertEqual(viewModel.breakOverlayMessagePlaceholderText, "Time to look away")
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
            launchAtLoginEnabled: true
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
        viewModel.updateLaunchAtLoginEnabled(true)
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
        viewModel.updateLaunchAtLoginEnabled(false)
        viewModel.updateBreakOverlayMessageText(AppConfig.defaultBreakOverlayMessageText)

        XCTAssertTrue(runtimeSettingsStore.updates.isEmpty)
        XCTAssertEqual(saveCallCount, 0)
        XCTAssertNil(viewModel.saveFailureMessage)
        XCTAssertFalse(viewModel.showsIdleAwayResetStepper)
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

    func testDefaultSaveDispatcherPersistsBeforeUpdateReturns() {
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

    func testBreakOverlayMessageDraftAppliesImmediatelyForNonEmptyText() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        viewModel.updateBreakOverlayMessageDraft("New message")

        XCTAssertEqual(viewModel.breakOverlayMessageText, "New message")
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "New message")
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, "New message")
    }

    func testBreakOverlayMessageDraftPreservesTypedWhitespaceWhileRuntimeNormalizesImmediately() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        viewModel.updateBreakOverlayMessageDraft(" \n\t ")

        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, " \n\t ")
        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)

        viewModel.commitBreakOverlayMessageDraft()

        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testPreviewSettingsViewInitializerBuildsFormBody() {
        let view = SettingsView(
            previewSettings: AppConfig(
                workDurationSeconds: 2_400,
                breakDurationSeconds: 45,
                idleAwayResetEnabled: true,
                idleAwayResetThresholdSeconds: 600,
                showStatusItemTimerState: true,
                breakOverlayMessageText: "Preview message",
                launchAtLoginEnabled: true
            )
        )

        XCTAssertTrue(String(describing: type(of: view.body)).contains("Form"))
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

        viewModel.updateLaunchAtLoginEnabled(true)

        XCTAssertEqual(
            runtimeSettingsStore.currentSettings,
            AppConfig(
                workDurationSeconds: 1_800,
                breakDurationSeconds: 45,
                idleAwayResetEnabled: true,
                idleAwayResetThresholdSeconds: 600,
                showStatusItemTimerState: true,
                breakOverlayMessageText: "External change",
                launchAtLoginEnabled: true
            )
        )
    }

    private func makeViewModel(
        runtimeSettingsStore: RuntimeSettingsStoring,
        saveConfig: @escaping SettingsViewModel.ConfigSaver = { _ in true }
    ) -> SettingsViewModel {
        SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: saveConfig,
            dispatchSave: { $0() }
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
