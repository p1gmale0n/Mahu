import AppKit
import SwiftUI
import XCTest
@testable import Mahu

@MainActor
final class SettingsNumericStepperFieldTests: XCTestCase {
    func testHostedNumericStepperFieldShowsCommittedValueAndStepper() {
        let controller = NSHostingController(
            rootView: NumericStepperFieldHarness()
        )
        let window = NSWindow(contentViewController: controller)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        controller.view.layoutSubtreeIfNeeded()

        let subviews = recursiveSubviews(in: controller.view)
        let textFields = subviews.compactMap { $0 as? NSTextField }
        let steppers = subviews.compactMap { $0 as? NSStepper }

        XCTAssertTrue(textFields.contains { $0.stringValue == "20" })
        XCTAssertEqual(steppers.count, 1)
    }

    func testHostedNumericStepperFieldKeepsEditableValueBeforeStepper() throws {
        let controller = NSHostingController(
            rootView: NumericStepperFieldHarness()
        )
        let window = NSWindow(contentViewController: controller)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        controller.view.layoutSubtreeIfNeeded()

        let textFields = recursiveSubviews(in: controller.view).compactMap { $0 as? NSTextField }
        let valueField = try XCTUnwrap(textFields.first { $0.isEditable && $0.stringValue == "20" })
        let stepper = try XCTUnwrap(recursiveSubviews(in: controller.view).compactMap { $0 as? NSStepper }.first)
        let valueFrame = valueField.convert(valueField.bounds, to: controller.view)
        let stepperFrame = stepper.convert(stepper.bounds, to: controller.view)

        XCTAssertTrue(valueField.isEditable)
        XCTAssertTrue((valueField.placeholderString ?? "").isEmpty)
        XCTAssertLessThanOrEqual(valueFrame.maxX, stepperFrame.minX)
    }

    func testHostedNumericStepperFieldCanHideVisibleTitleForInlineRows() {
        let controller = NSHostingController(
            rootView: HiddenTitleNumericStepperFieldHarness()
        )
        let window = NSWindow(contentViewController: controller)
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
        controller.view.layoutSubtreeIfNeeded()

        let textFields = recursiveSubviews(in: controller.view).compactMap { $0 as? NSTextField }

        XCTAssertTrue(textFields.contains { $0.isEditable && $0.stringValue == "5" })
        XCTAssertFalse(textFields.contains { $0.isEditable == false && $0.stringValue == "Idle away threshold" })
    }

    func testWorkDurationCommittedInputClampsToSupportedRange() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertEqual(viewModel.commitWorkDurationInput(0), 1)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.workDurationSeconds, 60)

        XCTAssertEqual(viewModel.commitWorkDurationInput(999), 180)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.workDurationSeconds, 10_800)
    }

    func testBreakDurationCommittedInputRoundsUpToNextStepAndClampsToRange() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertEqual(viewModel.commitBreakDurationInput(31), 35)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakDurationSeconds, 35)

        XCTAssertEqual(viewModel.commitBreakDurationInput(4), 5)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakDurationSeconds, 5)

        XCTAssertEqual(viewModel.commitBreakDurationInput(601), 600)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakDurationSeconds, 600)
    }

    func testIdleAwayThresholdCommittedInputClampsToSupportedRange() {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        let commitValue: (Int) -> Int = { minutes in
            viewModel.updateIdleAwayResetMinutes(minutes)
            return viewModel.idleAwayResetMinutes
        }

        XCTAssertEqual(commitValue(0), 1)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.idleAwayResetThresholdSeconds, 60)

        XCTAssertEqual(commitValue(999), 240)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.idleAwayResetThresholdSeconds, 14_400)
    }

    func testNumericFieldModelRejectsInvalidDraftAndRestoresLastCommittedValue() {
        let model = SettingsNumericStepperFieldModel(value: 20)

        model.updateDraftText("abc")

        XCTAssertEqual(model.commitDraftText(), .invalidInput)
        XCTAssertEqual(model.draftText, "20")
    }

    func testNumericFieldModelTrimsDraftAndCanonicalizesCommittedDisplayValue() {
        let model = SettingsNumericStepperFieldModel(value: 20)

        model.updateDraftText(" 021 ")

        XCTAssertEqual(model.commitDraftText(), .value(21))

        model.syncCommittedValue(25)

        XCTAssertEqual(model.committedValue, 25)
        XCTAssertEqual(model.draftText, "25")
    }

    func testNumericFieldModelWithoutRealEditsDoesNotCommitLegacyDisplayValue() {
        let model = SettingsNumericStepperFieldModel(value: 1)

        XCTAssertEqual(model.commitDraftText(), .noChange)
        XCTAssertEqual(model.committedValue, 1)
        XCTAssertEqual(model.draftText, "1")
    }

    func testNumericFieldModelEditedDraftMatchingCommittedValueStillCountsAsExplicitEdit() {
        let model = SettingsNumericStepperFieldModel(value: 1)

        model.updateDraftText("01")

        XCTAssertEqual(model.commitDraftText(), .value(1))
    }

    func testNumericFieldModelSyncCommittedValueReflectsImmediateStepperUpdates() {
        let model = SettingsNumericStepperFieldModel(value: 20)

        model.syncCommittedValue(45)

        XCTAssertEqual(model.committedValue, 45)
        XCTAssertEqual(model.draftText, "45")
    }

    func testIdleAwayThresholdEditabilityTracksFeatureToggleWhileDisplayTextStaysAvailable() {
        let startupConfig = AppConfig(
            workDurationSeconds: 1_200,
            breakDurationSeconds: 20,
            idleAwayResetEnabled: false,
            idleAwayResetThresholdSeconds: 14_500,
            showStatusItemTimerState: false,
            breakOverlayMessageText: AppConfig.defaultBreakOverlayMessageText,
            launchAtLoginEnabled: false
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let viewModel = makeViewModel(runtimeSettingsStore: runtimeSettingsStore)

        XCTAssertEqual(viewModel.idleAwayResetDisplayText, "240 min")
        XCTAssertFalse(viewModel.isIdleAwayThresholdEditable)

        viewModel.updateIdleAwayResetEnabled(true)

        XCTAssertTrue(viewModel.isIdleAwayThresholdEditable)
        XCTAssertEqual(viewModel.idleAwayResetDisplayText, "240 min")
    }

    private func makeViewModel(runtimeSettingsStore: RuntimeSettingsStoring) -> SettingsViewModel {
        SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in true }
        )
    }

    private func recursiveSubviews(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { recursiveSubviews(in: $0) }
    }
}

private struct NumericStepperFieldHarness: View {
    @State private var value = 20

    var body: some View {
        SettingsNumericStepperField(
            title: "Work Duration",
            unitText: "min",
            value: value,
            range: SettingsViewModel.workDurationMinutesRange,
            commitValue: { newValue in
                value = newValue
                return value
            },
            updateValue: { newValue in
                value = newValue
            }
        )
        .frame(width: 280)
    }
}

private struct HiddenTitleNumericStepperFieldHarness: View {
    @State private var value = 5

    var body: some View {
        SettingsNumericStepperField(
            title: "Idle away threshold",
            unitText: "min",
            showsTitle: false,
            value: value,
            range: SettingsViewModel.idleAwayMinutesRange,
            commitValue: { newValue in
                value = newValue
                return value
            },
            updateValue: { newValue in
                value = newValue
            }
        )
        .frame(width: 160)
    }
}
