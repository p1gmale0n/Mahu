import SwiftUI

enum SettingsNumericDraftCommitResult: Equatable {
    case noChange
    case invalidInput
    case value(Int)
}

final class SettingsNumericStepperFieldModel: ObservableObject {
    @Published private(set) var draftText: String

    let draftCommitRegistrationID = UUID()

    private(set) var committedValue: Int
    private var hasEditedDraftText = false

    init(value: Int) {
        committedValue = value
        draftText = String(value)
    }

    func updateDraftText(_ text: String) {
        guard draftText != text else {
            return
        }

        draftText = text
        hasEditedDraftText = true
    }

    func commitDraftText() -> SettingsNumericDraftCommitResult {
        guard hasEditedDraftText else {
            return .noChange
        }

        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedValue = Int(trimmedText) else {
            draftText = String(committedValue)
            hasEditedDraftText = false
            return .invalidInput
        }

        hasEditedDraftText = false
        return .value(parsedValue)
    }

    func syncCommittedValue(_ value: Int) {
        committedValue = value
        draftText = String(value)
        hasEditedDraftText = false
    }
}

struct SettingsNumericStepperField: View {
    @StateObject private var model: SettingsNumericStepperFieldModel
    @FocusState private var isTextFieldFocused: Bool

    private let title: String
    private let unitText: String
    private let showsTitle: Bool
    private let value: Int
    private let range: ClosedRange<Int>
    private let step: Int
    private let draftCommitter: SettingsDraftCommitter?
    private let commitValue: (Int) -> Int
    private let updateValue: (Int) -> Void

    init(
        title: String,
        unitText: String,
        showsTitle: Bool = true,
        value: Int,
        range: ClosedRange<Int>,
        step: Int = 1,
        draftCommitter: SettingsDraftCommitter? = nil,
        commitValue: @escaping (Int) -> Int,
        updateValue: @escaping (Int) -> Void
    ) {
        self.title = title
        self.unitText = unitText
        self.showsTitle = showsTitle
        self.value = value
        self.range = range
        self.step = step
        self.draftCommitter = draftCommitter
        self.commitValue = commitValue
        self.updateValue = updateValue
        _model = StateObject(wrappedValue: SettingsNumericStepperFieldModel(value: value))
    }

    var body: some View {
        rowContent
        .onChange(of: isTextFieldFocused) { _, focused in
            guard focused == false else {
                return
            }

            _ = commitDraftIfNeeded()
        }
        .onChange(of: value) { _, newValue in
            model.syncCommittedValue(newValue)
        }
        .onAppear(perform: registerDraftCloseCommit)
        .onDisappear(perform: unregisterDraftCloseCommit)
    }

    @ViewBuilder
    private var rowContent: some View {
        if showsTitle {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                numericControl
            }
        } else {
            numericControl
        }
    }

    @discardableResult
    private func commitDraftIfNeeded() -> SettingsDraftCommitDisposition {
        switch model.commitDraftText() {
        case .noChange:
            return .noChange
        case .invalidInput:
            return .noChange
        case .value(let parsedValue):
            let committedValue = commitValue(parsedValue)
            model.syncCommittedValue(committedValue)
            return .committedDraft
        }
    }

    private func registerDraftCloseCommit() {
        draftCommitter?.register(id: model.draftCommitRegistrationID) {
            commitDraftIfNeeded()
        }
    }

    private func unregisterDraftCloseCommit() {
        draftCommitter?.unregister(id: model.draftCommitRegistrationID)
    }

    @ViewBuilder
    var numericControl: some View {
        HStack(spacing: 8) {
            TextField("", text: Binding(get: { model.draftText }, set: model.updateDraftText))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 56)
                .focused($isTextFieldFocused)
                .accessibilityLabel(title)
                .onSubmit {
                    _ = commitDraftIfNeeded()
                }

            Text(unitText)
                .foregroundStyle(.secondary)

            Stepper(
                "",
                value: Binding(get: { value }, set: updateValue),
                in: range,
                step: step
            )
            .labelsHidden()
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
