import AppKit
import SwiftUI
import XCTest
@testable import Mahu

@MainActor
final class SettingsBreakOverlayMessageTests: XCTestCase {
    func testBreakOverlayMessageFooterTextExplainsFutureOverlayBehavior() {
        let viewModel = makeViewModel(runtimeSettingsStore: FakeRuntimeSettingsStore(currentSettings: .default))

        XCTAssertEqual(
            viewModel.breakOverlayMessageFooterText,
            "Shown on future break overlays. Press Return, change focus, or close Settings to apply it. Empty or whitespace-only text resets to the default message."
        )
    }

    func testHostedSettingsViewShowsCurrentBreakMessageWithoutPlaceholder() {
        let previewSettings = AppConfig(
            workDurationSeconds: 1_200,
            breakDurationSeconds: 20,
            breakOverlayMessageText: AppConfig.defaultBreakOverlayMessageText
        )
        let window = makeHostedWindow(rootView: SettingsView(previewSettings: previewSettings))
        let textFields = recursiveSubviews(in: window.contentView).compactMap { $0 as? NSTextField }
        let messageField = textFields.first {
            $0.isEditable &&
                $0.stringValue == AppConfig.defaultBreakOverlayMessageText
        }

        XCTAssertEqual(messageField?.stringValue, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(messageField?.isEditable, true)
        XCTAssertTrue((messageField?.placeholderString ?? "").isEmpty)
    }

    func testBreakOverlayMessageDraftPreservesTypedWhitespaceWithoutChangingCommittedRuntimeState() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        viewModel.updateBreakOverlayMessageDraft(" \n\t ")

        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, " \n\t ")
        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testBreakOverlayMessageDraftDoesNotApplyNonEmptyMessageUntilCommit() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        viewModel.updateBreakOverlayMessageDraft("Next break message")

        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "Next break message")
        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testBreakOverlayMessageCommitNormalizesWhitespaceDraftToDefaultValue() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        viewModel.updateBreakOverlayMessageDraft(" \n\t ")
        viewModel.commitBreakOverlayMessageDraft()

        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testBreakOverlayMessageCommitAppliesDraftAndClearsSaveWarningAfterRetry() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        var saveResults = [false, true]
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in
                saveResults.removeFirst()
            }
        )

        viewModel.updateBreakOverlayMessageDraft("Next break message")
        viewModel.commitBreakOverlayMessageDraft()

        XCTAssertEqual(viewModel.breakOverlayMessageText, "Next break message")
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "Next break message")
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, "Next break message")
        XCTAssertNotNil(viewModel.saveFailureMessage)

        viewModel.commitBreakOverlayMessageDraft()

        XCTAssertNil(viewModel.saveFailureMessage)
        XCTAssertEqual(viewModel.breakOverlayMessageText, "Next break message")
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, "Next break message")
    }

    func testRejectedOversizedBreakMessageDraftSurvivesSuccessfulUnrelatedSettingsSave() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let oversizedDraft = String(repeating: "x", count: 64)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in true },
            canPersistConfig: { config in
                config.breakOverlayMessageText.utf8.count <= 32
            }
        )

        viewModel.updateBreakOverlayMessageDraft(oversizedDraft)
        viewModel.commitBreakOverlayMessageDraft()
        viewModel.updateShowMenuTimer(true)

        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, oversizedDraft)
        XCTAssertTrue(viewModel.showMenuTimer)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(
            viewModel.saveFailureMessage,
            "This Settings value is too large to save to config.json. Mahu keeps the previous saved value active until you reduce it."
        )
    }

    func testEditingRejectedOversizedBreakMessageDraftBackIntoPersistableRangeClearsWarningWithoutApplyingYet() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in true },
            canPersistConfig: { config in
                config.breakOverlayMessageText.utf8.count <= 32
            }
        )

        viewModel.updateBreakOverlayMessageDraft(String(repeating: "x", count: 64))
        viewModel.commitBreakOverlayMessageDraft()

        viewModel.updateBreakOverlayMessageDraft("Short message")

        XCTAssertNil(viewModel.saveFailureMessage)
        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "Short message")
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
    }

    private func makeViewModel(runtimeSettingsStore: RuntimeSettingsStoring) -> SettingsViewModel {
        SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in true }
        )
    }

    private func makeHostedWindow(rootView: some View) -> NSWindow {
        let controller = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: controller)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        controller.view.layoutSubtreeIfNeeded()
        return window
    }

    private func recursiveSubviews(in view: NSView?) -> [NSView] {
        guard let view else {
            return []
        }

        return [view] + view.subviews.flatMap { recursiveSubviews(in: $0) }
    }
}
