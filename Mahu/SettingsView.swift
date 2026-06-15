import SwiftUI

struct SettingsView: View {
    static let minimumContentWidth: CGFloat = 500
    static let minimumContentHeight: CGFloat = 460
    static let preferredContentWidth: CGFloat = 640
    static let preferredContentHeight: CGFloat = 660

    private static let formLabelColumnWidth: CGFloat = 220
    private static let formRowSpacing: CGFloat = 12
    private static let formRowMinHeight: CGFloat = 28
    private static let breakOverlayMessageFieldMinWidth: CGFloat = 240
    private static let breakOverlayMessageFieldIdealWidth: CGFloat = 300
    private static let breakOverlayMessageFieldMaxWidth: CGFloat = 320

    private enum FocusedField {
        case breakOverlayMessage
    }

    @ObservedObject private var viewModel: SettingsViewModel
    @FocusState private var focusedField: FocusedField?
    @State private var breakOverlayMessageDraftRegistrationID = UUID()

    private let draftCommitter: SettingsDraftCommitter?

    init(
        viewModel: SettingsViewModel,
        draftCommitter: SettingsDraftCommitter? = nil
    ) {
        self.viewModel = viewModel
        self.draftCommitter = draftCommitter
    }

    init(previewSettings: AppConfig = .default) {
        self.init(
            viewModel: SettingsViewModel(
                runtimeSettingsStore: RuntimeSettingsStore(initialSettings: previewSettings),
                saveConfig: { _ in true }
            )
        )
    }

    var body: some View {
        Form {
            Section {
                settingsControlRow(title: "Work Duration") {
                    SettingsNumericStepperField(
                        title: "Work Duration",
                        unitText: "min",
                        showsTitle: false,
                        value: viewModel.workDurationMinutes,
                        range: SettingsViewModel.workDurationMinutesRange,
                        draftCommitter: draftCommitter,
                        commitValue: viewModel.commitWorkDurationInput,
                        updateValue: viewModel.updateWorkDurationMinutes
                    )
                }

                settingsControlRow(title: "Break Duration") {
                    SettingsNumericStepperField(
                        title: "Break Duration",
                        unitText: "sec",
                        showsTitle: false,
                        value: viewModel.breakDurationSeconds,
                        range: SettingsViewModel.breakDurationSecondsRange,
                        step: SettingsViewModel.breakDurationStepSeconds,
                        draftCommitter: draftCommitter,
                        commitValue: viewModel.commitBreakDurationInput,
                        updateValue: viewModel.updateBreakDurationSeconds
                    )
                }
            } header: {
                Text("Timers")
            } footer: {
                if let noticeText = viewModel.supportedValueNormalizationNoticeText {
                    Label(noticeText, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                settingsControlRow(title: "Launch at login") {
                    Toggle("", isOn: .constant(viewModel.launchAtLoginEnabled))
                        .labelsHidden()
                        .disabled(true)
                        .accessibilityLabel("Launch at login")
                }
            } header: {
                Text("General")
            } footer: {
                Label {
                    Text(viewModel.launchAtLoginFooterText)
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Section {
                settingsControlRow(title: "Also reset timer when inactive for") {
                    HStack(spacing: Self.formRowSpacing) {
                        SettingsNumericStepperField(
                            title: "Idle away threshold",
                            unitText: "min",
                            showsTitle: false,
                            value: viewModel.idleAwayResetMinutes,
                            range: SettingsViewModel.idleAwayMinutesRange,
                            draftCommitter: draftCommitter,
                            commitValue: viewModel.commitIdleAwayResetInput,
                            updateValue: viewModel.updateIdleAwayResetMinutes
                        )
                        .disabled(viewModel.isIdleAwayThresholdEditable == false)

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { viewModel.idleAwayResetEnabled },
                                set: viewModel.updateIdleAwayResetEnabled
                            )
                        )
                        .labelsHidden()
                        .accessibilityLabel("Reset timer when inactive")
                    }
                }
            } header: {
                Text("Away Behavior")
            } footer: {
                Text(viewModel.awayBehaviorFooterText)
                    .foregroundStyle(.secondary)
            }

            Section {
                settingsControlRow(title: "Show timer in menu bar") {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { viewModel.showMenuTimer },
                            set: viewModel.updateShowMenuTimer
                        )
                    )
                    .labelsHidden()
                    .accessibilityLabel("Show timer in menu bar")
                }

                settingsControlRow(title: "Break overlay message") {
                    TextField(
                        "",
                        text: Binding(
                            get: { viewModel.breakOverlayMessageDraftText },
                            set: viewModel.updateBreakOverlayMessageDraft
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    .frame(
                        minWidth: Self.breakOverlayMessageFieldMinWidth,
                        idealWidth: Self.breakOverlayMessageFieldIdealWidth,
                        maxWidth: Self.breakOverlayMessageFieldMaxWidth,
                        alignment: .leading
                    )
                    .focused($focusedField, equals: .breakOverlayMessage)
                    .accessibilityLabel("Break overlay message")
                    .onSubmit {
                        viewModel.commitBreakOverlayMessageDraft()
                    }
                    .onChange(of: focusedField) { _, newValue in
                        guard newValue != .breakOverlayMessage else {
                            return
                        }

                        viewModel.commitBreakOverlayMessageDraft()
                    }
                }
            } header: {
                Text("Display")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.breakOverlayMessageFooterText)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let saveWarningText = viewModel.saveWarningText {
                        Label(saveWarningText, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(
            minWidth: Self.minimumContentWidth,
            idealWidth: Self.preferredContentWidth,
            minHeight: Self.minimumContentHeight,
            idealHeight: Self.preferredContentHeight
        )
        .onAppear(perform: registerDraftCloseCommit)
        .onDisappear {
            unregisterDraftCloseCommit()
            viewModel.commitBreakOverlayMessageDraft()
        }
    }

    private func settingsControlRow<Control: View>(
        title: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: Self.formRowSpacing) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: Self.formLabelColumnWidth, alignment: .leading)

            Spacer(minLength: Self.formRowSpacing)

            control()
        }
        .frame(minHeight: Self.formRowMinHeight, alignment: .center)
    }

    private func registerDraftCloseCommit() {
        draftCommitter?.register(id: breakOverlayMessageDraftRegistrationID) {
            let hadUncommittedDraft = viewModel.breakOverlayMessageDraftText != viewModel.breakOverlayMessageText
            viewModel.commitBreakOverlayMessageDraft()
            return hadUncommittedDraft ? .committedDraft : .noChange
        }
    }

    private func unregisterDraftCloseCommit() {
        draftCommitter?.unregister(id: breakOverlayMessageDraftRegistrationID)
    }
}

#Preview {
    SettingsView(previewSettings: .default)
}
