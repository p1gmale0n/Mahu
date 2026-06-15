import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    typealias ConfigSaver = (AppConfig) -> Bool
    typealias ConfigPersistenceValidator = (AppConfig) -> Bool

    static let workDurationMinutesRange = 1...180
    static let breakDurationSecondsRange = 5...600
    static let breakDurationStepSeconds = 5
    static let idleAwayMinutesRange = 1...240
    private static let configSaveFailureWarningMessage = "Couldn't save settings to config.json. Mahu keeps the current in-app settings active, but system-integrated changes may already have taken effect."
    private static let oversizedSettingsValueMessage = "This Settings value is too large to save to config.json. Mahu keeps the previous saved value active until you reduce it."

    @Published private(set) var workDurationMinutes: Int
    @Published private(set) var breakDurationSeconds: Int
    @Published private(set) var idleAwayResetEnabled: Bool
    @Published private(set) var idleAwayResetMinutes: Int
    @Published private(set) var showMenuTimer: Bool
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var breakOverlayMessageText: String
    @Published private(set) var breakOverlayMessageDraftText: String
    @Published private(set) var supportedValueNormalizationNoticeText: String?
    @Published private(set) var saveWarningRevision = 0
    @Published private var configSaveFailureMessage: String?
    @Published private var breakOverlayMessageDraftWarningMessage: String?

    private let runtimeSettingsStore: RuntimeSettingsStoring
    private let saveConfig: ConfigSaver
    private let canPersistConfig: ConfigPersistenceValidator
    private var cancelRuntimeSettingsObservation: (() -> Void)?
    private var currentSettings: AppConfig
    private var isApplyingLocalRuntimeUpdate = false

    init(
        runtimeSettingsStore: RuntimeSettingsStoring,
        saveConfig: @escaping ConfigSaver,
        canPersistConfig: @escaping ConfigPersistenceValidator = { _ in true }
    ) {
        self.runtimeSettingsStore = runtimeSettingsStore
        self.saveConfig = saveConfig
        self.canPersistConfig = canPersistConfig

        let currentSettings = runtimeSettingsStore.currentSettings
        let uiSettings = SettingsValueMapper.canonicalUISettings(from: currentSettings)
        self.currentSettings = currentSettings
        self.workDurationMinutes = SettingsValueMapper.workDurationMinutes(from: uiSettings.workDurationSeconds)
        self.breakDurationSeconds = SettingsValueMapper.breakDurationSeconds(from: uiSettings.breakDurationSeconds)
        self.idleAwayResetEnabled = uiSettings.idleAwayResetEnabled
        self.idleAwayResetMinutes = SettingsValueMapper.idleAwayResetMinutes(from: uiSettings.idleAwayResetThresholdSeconds)
        self.showMenuTimer = uiSettings.showStatusItemTimerState
        self.launchAtLoginEnabled = uiSettings.launchAtLoginEnabled
        self.breakOverlayMessageText = currentSettings.breakOverlayMessageText
        self.breakOverlayMessageDraftText = currentSettings.breakOverlayMessageText
        self.supportedValueNormalizationNoticeText = SettingsValueMapper.supportedValueNormalizationNoticeText(
            for: currentSettings,
            uiSettings: uiSettings
        )
        cancelRuntimeSettingsObservation = runtimeSettingsStore.addObserver { [weak self] newSettings in
            guard let self, self.isApplyingLocalRuntimeUpdate == false else {
                return
            }
            self.refreshPublishedState(from: newSettings)
        }
    }
    deinit {
        cancelRuntimeSettingsObservation?()
    }

    var hasSaveFailure: Bool {
        saveWarningText != nil
    }

    var workDurationDisplayText: String { "\(workDurationMinutes) min" }
    var breakDurationDisplayText: String { "\(breakDurationSeconds) sec" }
    var idleAwayResetDisplayText: String { "\(idleAwayResetMinutes) min" }
    var isIdleAwayThresholdEditable: Bool { idleAwayResetEnabled }

    var launchAtLoginFooterText: String {
        "This row reflects the current Launch at Login desired state from config/runtime. Change it through config.json or signing-supported Login Item flows; the Settings toggle is read-only."
    }

    var awayBehaviorFooterText: String {
        "Mahu always resets the timer when your screen is locked or your Mac goes to sleep."
    }

    var breakOverlayMessageFooterText: String {
        "Shown on future break overlays. Press Return, change focus, or close Settings to apply it. Empty or whitespace-only text resets to the default message."
    }

    var saveFailureMessage: String? { saveWarningText }
    var saveWarningText: String? {
        SettingsWarningTextComposer.compose(
            primary: breakOverlayMessageDraftWarningMessage,
            secondary: configSaveFailureMessage
        )
    }

    func updateWorkDurationMinutes(_ minutes: Int) {
        performSaveWarningTrackedMutation {
            applyUpdatedSettings(
                currentSettings.updating(
                    workDurationSeconds: TimeInterval(SettingsValueMapper.normalizeWorkDurationMinutes(minutes) * 60)
                )
            )
        }
    }

    func commitWorkDurationInput(_ minutes: Int) -> Int {
        updateWorkDurationMinutes(minutes)
        return workDurationMinutes
    }

    func updateBreakDurationSeconds(_ seconds: Int) {
        performSaveWarningTrackedMutation {
            applyUpdatedSettings(
                currentSettings.updating(
                    breakDurationSeconds: TimeInterval(SettingsValueMapper.normalizeBreakDurationSeconds(seconds))
                )
            )
        }
    }

    func commitBreakDurationInput(_ seconds: Int) -> Int {
        updateBreakDurationSeconds(seconds)
        return breakDurationSeconds
    }

    func updateIdleAwayResetEnabled(_ enabled: Bool) {
        performSaveWarningTrackedMutation {
            applyUpdatedSettings(
                currentSettings.updating(idleAwayResetEnabled: enabled)
            )
        }
    }

    func updateIdleAwayResetMinutes(_ minutes: Int) {
        performSaveWarningTrackedMutation {
            applyUpdatedSettings(
                currentSettings.updating(
                    idleAwayResetThresholdSeconds: TimeInterval(
                        SettingsValueMapper.normalizeIdleAwayResetMinutes(minutes) * 60
                    )
                )
            )
        }
    }

    func commitIdleAwayResetInput(_ minutes: Int) -> Int {
        updateIdleAwayResetMinutes(minutes)
        return idleAwayResetMinutes
    }

    func updateShowMenuTimer(_ enabled: Bool) {
        performSaveWarningTrackedMutation {
            applyUpdatedSettings(
                currentSettings.updating(showStatusItemTimerState: enabled)
            )
        }
    }

    func updateBreakOverlayMessageDraft(_ text: String) {
        performSaveWarningTrackedMutation {
            breakOverlayMessageDraftText = text
            clearBreakOverlayMessageDraftWarningIfResolved(by: text)
        }
    }

    func commitBreakOverlayMessageDraft() {
        updateBreakOverlayMessageText(breakOverlayMessageDraftText)
    }

    func updateBreakOverlayMessageText(_ text: String) {
        performSaveWarningTrackedMutation {
            let newSettings = currentSettings.updating(
                breakOverlayMessageText: AppConfig.normalizedBreakOverlayMessageText(text)
            )

            guard newSettings != currentSettings else {
                refreshPublishedState(from: currentSettings)
                retryCurrentSettingsPersistenceIfNeeded()
                return
            }

            guard canPersistConfig(newSettings) else {
                refreshPublishedState(from: currentSettings, preservingDraftText: text)
                breakOverlayMessageDraftWarningMessage = Self.oversizedSettingsValueMessage
                return
            }

            breakOverlayMessageDraftWarningMessage = nil
            applyUpdatedSettings(newSettings)
        }
    }

    private func performSaveWarningTrackedMutation(_ mutation: () -> Void) {
        let previousSaveWarningText = saveWarningText
        mutation()

        if saveWarningText != previousSaveWarningText {
            saveWarningRevision &+= 1
        }
    }

    private func applyUpdatedSettings(
        _ newSettings: AppConfig,
        preservingDraftText preservedDraftText: String? = nil
    ) {
        guard newSettings != currentSettings else {
            retryCurrentSettingsPersistenceIfNeeded()
            return
        }

        isApplyingLocalRuntimeUpdate = true
        runtimeSettingsStore.update(newSettings)
        isApplyingLocalRuntimeUpdate = false

        let acceptedSettings = runtimeSettingsStore.currentSettings
        guard acceptedSettings == newSettings else {
            refreshPublishedState(from: acceptedSettings)
            return
        }

        refreshPublishedState(from: acceptedSettings, preservingDraftText: preservedDraftText)
        persistAcceptedSettings(acceptedSettings)
    }

    private func refreshPublishedState(
        from settings: AppConfig,
        preservingDraftText preservedDraftText: String? = nil
    ) {
        let uiSettings = SettingsValueMapper.canonicalUISettings(from: settings)
        currentSettings = settings
        workDurationMinutes = SettingsValueMapper.workDurationMinutes(from: uiSettings.workDurationSeconds)
        breakDurationSeconds = SettingsValueMapper.breakDurationSeconds(from: uiSettings.breakDurationSeconds)
        idleAwayResetEnabled = uiSettings.idleAwayResetEnabled
        idleAwayResetMinutes = SettingsValueMapper.idleAwayResetMinutes(from: uiSettings.idleAwayResetThresholdSeconds)
        showMenuTimer = uiSettings.showStatusItemTimerState
        launchAtLoginEnabled = uiSettings.launchAtLoginEnabled
        breakOverlayMessageText = settings.breakOverlayMessageText
        breakOverlayMessageDraftText = preservedDraftText ?? resolvedBreakOverlayMessageDraftText(for: settings)
        supportedValueNormalizationNoticeText = SettingsValueMapper.supportedValueNormalizationNoticeText(
            for: settings,
            uiSettings: uiSettings
        )
    }

    private func resolvedBreakOverlayMessageDraftText(for settings: AppConfig) -> String {
        if breakOverlayMessageDraftWarningMessage != nil {
            return breakOverlayMessageDraftText
        }

        return settings.breakOverlayMessageText
    }

    private func clearBreakOverlayMessageDraftWarningIfResolved(by text: String) {
        guard breakOverlayMessageDraftWarningMessage != nil else {
            return
        }

        if text == currentSettings.breakOverlayMessageText {
            breakOverlayMessageDraftWarningMessage = nil
            return
        }

        let candidateSettings = currentSettings.updating(
            breakOverlayMessageText: AppConfig.normalizedBreakOverlayMessageText(text)
        )
        if canPersistConfig(candidateSettings) {
            breakOverlayMessageDraftWarningMessage = nil
        }
    }

    private func persistAcceptedSettings(_ settings: AppConfig) {
        applySaveResult(saveConfig(settings))
    }

    private func retryCurrentSettingsPersistenceIfNeeded() {
        guard configSaveFailureMessage != nil else {
            return
        }

        persistAcceptedSettings(currentSettings)
    }

    private func applySaveResult(_ didSave: Bool) {
        configSaveFailureMessage = didSave ? nil : Self.configSaveFailureWarningMessage
    }
}
