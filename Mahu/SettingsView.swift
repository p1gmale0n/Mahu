import SwiftUI

struct SettingsView: View {
    private enum FocusedField {
        case breakOverlayMessage
    }

    @ObservedObject private var viewModel: SettingsViewModel
    @FocusState private var focusedField: FocusedField?

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
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
                Stepper(
                    value: Binding(
                        get: { viewModel.workDurationMinutes },
                        set: viewModel.updateWorkDurationMinutes
                    ),
                    in: SettingsViewModel.workDurationMinutesRange
                ) {
                    LabeledContent("Work Duration") {
                        Text(viewModel.workDurationDisplayText)
                            .monospacedDigit()
                    }
                }

                Stepper(
                    value: Binding(
                        get: { viewModel.breakDurationSeconds },
                        set: viewModel.updateBreakDurationSeconds
                    ),
                    in: SettingsViewModel.breakDurationSecondsRange,
                    step: SettingsViewModel.breakDurationStepSeconds
                ) {
                    LabeledContent("Break Duration") {
                        Text(viewModel.breakDurationDisplayText)
                            .monospacedDigit()
                    }
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
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { viewModel.launchAtLoginEnabled },
                        set: viewModel.updateLaunchAtLoginEnabled
                    )
                )
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
                Toggle(
                    isOn: Binding(
                        get: { viewModel.idleAwayResetEnabled },
                        set: viewModel.updateIdleAwayResetEnabled
                    )
                ) {
                    HStack(spacing: 8) {
                        Text("Also reset timer when inactive for")

                        if viewModel.showsIdleAwayResetStepper {
                            Stepper(
                                value: Binding(
                                    get: { viewModel.idleAwayResetMinutes },
                                    set: viewModel.updateIdleAwayResetMinutes
                                ),
                                in: SettingsViewModel.idleAwayMinutesRange
                            ) {
                                Text(viewModel.idleAwayResetDisplayText)
                                    .monospacedDigit()
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
            } header: {
                Text("Away Behavior")
            } footer: {
                Text(viewModel.awayBehaviorFooterText)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(
                    "Show timer in menu bar",
                    isOn: Binding(
                        get: { viewModel.showMenuTimer },
                        set: viewModel.updateShowMenuTimer
                    )
                )

                LabeledContent("Break overlay message") {
                    TextField(
                        viewModel.breakOverlayMessagePlaceholderText,
                        text: Binding(
                            get: { viewModel.breakOverlayMessageDraftText },
                            set: viewModel.updateBreakOverlayMessageDraft
                        )
                    )
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 220)
                    .focused($focusedField, equals: .breakOverlayMessage)
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
                if let saveWarningText = viewModel.saveWarningText {
                    Label(saveWarningText, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, idealWidth: 460, minHeight: 360, idealHeight: 420)
        .onDisappear {
            viewModel.commitBreakOverlayMessageDraft()
        }
    }
}

#Preview {
    SettingsView(previewSettings: .default)
}
