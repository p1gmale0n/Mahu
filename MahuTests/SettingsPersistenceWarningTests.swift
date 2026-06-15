import XCTest
@testable import Mahu

@MainActor
final class SettingsPersistenceWarningTests: XCTestCase {
    func testRepeatedSameNonMessageUpdateRetriesPreviousSaveFailure() {
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
        XCTAssertTrue(runtimeSettingsStore.currentSettings.showStatusItemTimerState)

        viewModel.updateShowMenuTimer(true)

        XCTAssertNil(viewModel.saveFailureMessage)
        XCTAssertTrue(runtimeSettingsStore.currentSettings.showStatusItemTimerState)
        XCTAssertTrue(saveResults.isEmpty)
    }

    func testOversizedDraftWarningDoesNotMaskUnrelatedSaveFailure() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let oversizedDraft = String(repeating: "x", count: 64)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in false },
            canPersistConfig: { config in
                config.breakOverlayMessageText.utf8.count <= 32
            }
        )

        viewModel.updateBreakOverlayMessageDraft(oversizedDraft)
        viewModel.commitBreakOverlayMessageDraft()
        viewModel.updateShowMenuTimer(true)

        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, oversizedDraft)
        XCTAssertTrue(viewModel.showMenuTimer)
        XCTAssertEqual(
            viewModel.saveWarningText,
            """
            This Settings value is too large to save to config.json. Mahu keeps the previous saved value active until you reduce it.

            Couldn't save settings to config.json. Mahu keeps the current in-app settings active, but system-integrated changes may already have taken effect.
            """
        )
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
