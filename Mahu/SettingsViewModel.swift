import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    typealias ConfigSaver = (AppConfig) -> Bool
    typealias SaveDispatcher = (@escaping @Sendable () -> Void) -> Void

    static let workDurationMinutesRange = 1...180
    static let breakDurationSecondsRange = 5...600
    static let breakDurationStepSeconds = 5
    static let idleAwayMinutesRange = 1...240
    private static let saveFailureMessage = "Couldn't save settings to config.json. Mahu keeps the current in-app settings active, but system-integrated changes may already have taken effect."
    private static let supportedValueNormalizationNotice = "Some timer values loaded from config.json are outside the Settings UI ranges. Mahu is showing the nearest supported values here, but the current runtime and config keep each raw value until you edit that specific control."

    @Published private(set) var workDurationMinutes: Int
    @Published private(set) var breakDurationSeconds: Int
    @Published private(set) var idleAwayResetEnabled: Bool
    @Published private(set) var idleAwayResetMinutes: Int
    @Published private(set) var showMenuTimer: Bool
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var breakOverlayMessageText: String
    @Published private(set) var breakOverlayMessageDraftText: String
    @Published private(set) var supportedValueNormalizationNoticeText: String?
    @Published private(set) var saveFailureMessage: String?

    private let runtimeSettingsStore: RuntimeSettingsStoring
    private let saveConfig: ConfigSaver
    private let dispatchSave: SaveDispatcher
    private var cancelRuntimeSettingsObservation: (() -> Void)?
    private var currentSettings: AppConfig
    private var isApplyingLocalRuntimeUpdate = false
    private var latestSaveGeneration = 0

    init(
        runtimeSettingsStore: RuntimeSettingsStoring,
        saveConfig: @escaping ConfigSaver,
        dispatchSave: @escaping SaveDispatcher = { work in work() }
    ) {
        self.runtimeSettingsStore = runtimeSettingsStore
        self.saveConfig = saveConfig
        self.dispatchSave = dispatchSave

        let currentSettings = runtimeSettingsStore.currentSettings
        let uiSettings = Self.canonicalUISettings(from: currentSettings)
        self.currentSettings = currentSettings
        self.workDurationMinutes = Self.workDurationMinutes(from: uiSettings.workDurationSeconds)
        self.breakDurationSeconds = Self.breakDurationSeconds(from: uiSettings.breakDurationSeconds)
        self.idleAwayResetEnabled = uiSettings.idleAwayResetEnabled
        self.idleAwayResetMinutes = Self.idleAwayResetMinutes(from: uiSettings.idleAwayResetThresholdSeconds)
        self.showMenuTimer = uiSettings.showStatusItemTimerState
        self.launchAtLoginEnabled = uiSettings.launchAtLoginEnabled
        self.breakOverlayMessageText = currentSettings.breakOverlayMessageText
        self.breakOverlayMessageDraftText = currentSettings.breakOverlayMessageText
        self.supportedValueNormalizationNoticeText = Self.supportedValueNormalizationNoticeText(
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
        saveFailureMessage != nil
    }

    var workDurationDisplayText: String { "\(workDurationMinutes) min" }
    var breakDurationDisplayText: String { "\(breakDurationSeconds) sec" }
    var idleAwayResetDisplayText: String { "\(idleAwayResetMinutes) min" }
    var showsIdleAwayResetStepper: Bool { idleAwayResetEnabled }

    var launchAtLoginFooterText: String {
        "Mahu treats Launch at Login as a desired state. macOS may still require a signed app and Login Items approval before registration succeeds."
    }

    var awayBehaviorFooterText: String {
        "Mahu always resets the timer when your screen is locked or your Mac goes to sleep."
    }

    var breakOverlayMessagePlaceholderText: String { "Time to look away" }

    var saveWarningText: String? { saveFailureMessage }

    func updateWorkDurationMinutes(_ minutes: Int) {
        applyUpdatedSettings(
            currentSettings.updating(
                workDurationSeconds: TimeInterval(Self.normalizeWorkDurationMinutes(minutes) * 60)
            )
        )
    }

    func updateBreakDurationSeconds(_ seconds: Int) {
        applyUpdatedSettings(
            currentSettings.updating(
                breakDurationSeconds: TimeInterval(Self.normalizeBreakDurationSeconds(seconds))
            )
        )
    }

    func updateIdleAwayResetEnabled(_ enabled: Bool) {
        applyUpdatedSettings(
            currentSettings.updating(idleAwayResetEnabled: enabled)
        )
    }

    func updateIdleAwayResetMinutes(_ minutes: Int) {
        applyUpdatedSettings(
            currentSettings.updating(
                idleAwayResetThresholdSeconds: TimeInterval(
                    Self.normalizeIdleAwayResetMinutes(minutes) * 60
                )
            )
        )
    }

    func updateShowMenuTimer(_ enabled: Bool) {
        applyUpdatedSettings(
            currentSettings.updating(showStatusItemTimerState: enabled)
        )
    }

    func updateLaunchAtLoginEnabled(_ enabled: Bool) {
        applyUpdatedSettings(
            currentSettings.updating(launchAtLoginEnabled: enabled)
        )
    }

    func updateBreakOverlayMessageDraft(_ text: String) {
        breakOverlayMessageDraftText = text

        let newSettings = currentSettings.updating(
            breakOverlayMessageText: AppConfig.normalizedBreakOverlayMessageText(text)
        )

        applyUpdatedSettings(newSettings, preservingDraftText: text)
    }

    func commitBreakOverlayMessageDraft() {
        updateBreakOverlayMessageText(breakOverlayMessageDraftText)
    }

    func updateBreakOverlayMessageText(_ text: String) {
        let newSettings = currentSettings.updating(
            breakOverlayMessageText: AppConfig.normalizedBreakOverlayMessageText(text)
        )

        guard newSettings != currentSettings else {
            refreshPublishedState(from: currentSettings)
            return
        }

        applyUpdatedSettings(newSettings)
    }

    private func applyUpdatedSettings(
        _ newSettings: AppConfig,
        preservingDraftText preservedDraftText: String? = nil
    ) {
        guard newSettings != currentSettings else {
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
        let uiSettings = Self.canonicalUISettings(from: settings)
        currentSettings = settings
        workDurationMinutes = Self.workDurationMinutes(from: uiSettings.workDurationSeconds)
        breakDurationSeconds = Self.breakDurationSeconds(from: uiSettings.breakDurationSeconds)
        idleAwayResetEnabled = uiSettings.idleAwayResetEnabled
        idleAwayResetMinutes = Self.idleAwayResetMinutes(from: uiSettings.idleAwayResetThresholdSeconds)
        showMenuTimer = uiSettings.showStatusItemTimerState
        launchAtLoginEnabled = uiSettings.launchAtLoginEnabled
        breakOverlayMessageText = settings.breakOverlayMessageText
        breakOverlayMessageDraftText = preservedDraftText ?? settings.breakOverlayMessageText
        supportedValueNormalizationNoticeText = Self.supportedValueNormalizationNoticeText(
            for: settings,
            uiSettings: uiSettings
        )
    }

    private func persistAcceptedSettings(_ settings: AppConfig) {
        latestSaveGeneration += 1
        let saveGeneration = latestSaveGeneration
        let saveConfig = self.saveConfig

        dispatchSave {
            let didSave = saveConfig(settings)
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self.applySaveResult(didSave, saveGeneration: saveGeneration)
                }
                return
            }

            Task { @MainActor [weak self] in
                self?.applySaveResult(didSave, saveGeneration: saveGeneration)
            }
        }
    }

    private func applySaveResult(_ didSave: Bool, saveGeneration: Int) {
        guard saveGeneration == latestSaveGeneration else { return }
        saveFailureMessage = didSave ? nil : Self.saveFailureMessage
    }

    private static func workDurationMinutes(from seconds: TimeInterval) -> Int {
        normalizeWorkDurationMinutes(roundedUpMinutes(from: seconds))
    }

    private static func breakDurationSeconds(from seconds: TimeInterval) -> Int {
        normalizeBreakDurationSeconds(roundedUpWholeSeconds(from: seconds))
    }

    private static func idleAwayResetMinutes(from seconds: TimeInterval) -> Int {
        normalizeIdleAwayResetMinutes(roundedUpMinutes(from: seconds))
    }

    private static func roundedUpMinutes(from seconds: TimeInterval) -> Int {
        let wholeSeconds = roundedUpWholeSeconds(from: seconds)
        return max(1, (wholeSeconds + 59) / 60)
    }

    private static func roundedUpWholeSeconds(from seconds: TimeInterval) -> Int {
        Int(clamping: AppConfig.safeDisplayWholeSeconds(seconds))
    }

    private static func normalizeWorkDurationMinutes(_ minutes: Int) -> Int {
        clamp(minutes, to: workDurationMinutesRange)
    }

    private static func normalizeBreakDurationSeconds(_ seconds: Int) -> Int {
        let clampedSeconds = clamp(seconds, to: breakDurationSecondsRange)
        let roundedToStep = ((clampedSeconds + (breakDurationStepSeconds - 1)) / breakDurationStepSeconds) * breakDurationStepSeconds
        return min(breakDurationSecondsRange.upperBound, roundedToStep)
    }

    private static func normalizeIdleAwayResetMinutes(_ minutes: Int) -> Int {
        clamp(minutes, to: idleAwayMinutesRange)
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func canonicalUISettings(from settings: AppConfig) -> AppConfig {
        AppConfig(
            workDurationSeconds: TimeInterval(workDurationMinutes(from: settings.workDurationSeconds) * 60),
            breakDurationSeconds: TimeInterval(breakDurationSeconds(from: settings.breakDurationSeconds)),
            idleAwayResetEnabled: settings.idleAwayResetEnabled,
            idleAwayResetThresholdSeconds: TimeInterval(
                idleAwayResetMinutes(from: settings.idleAwayResetThresholdSeconds) * 60
            ),
            showStatusItemTimerState: settings.showStatusItemTimerState,
            breakOverlayMessageText: settings.breakOverlayMessageText,
            launchAtLoginEnabled: settings.launchAtLoginEnabled
        )
    }

    private static func supportedValueNormalizationNoticeText(
        for settings: AppConfig,
        uiSettings: AppConfig
    ) -> String? {
        settings == uiSettings ? nil : supportedValueNormalizationNotice
    }
}
