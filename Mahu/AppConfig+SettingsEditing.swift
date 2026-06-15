import Foundation

extension AppConfig {
    func updating(
        workDurationSeconds: TimeInterval? = nil,
        breakDurationSeconds: TimeInterval? = nil,
        idleAwayResetEnabled: Bool? = nil,
        idleAwayResetThresholdSeconds: TimeInterval? = nil,
        showStatusItemTimerState: Bool? = nil,
        breakOverlayMessageText: String? = nil,
        launchAtLoginEnabled: Bool? = nil
    ) -> AppConfig {
        AppConfig(
            workDurationSeconds: workDurationSeconds ?? self.workDurationSeconds,
            breakDurationSeconds: breakDurationSeconds ?? self.breakDurationSeconds,
            idleAwayResetEnabled: idleAwayResetEnabled ?? self.idleAwayResetEnabled,
            idleAwayResetThresholdSeconds: idleAwayResetThresholdSeconds ?? self.idleAwayResetThresholdSeconds,
            showStatusItemTimerState: showStatusItemTimerState ?? self.showStatusItemTimerState,
            breakOverlayMessageText: breakOverlayMessageText ?? self.breakOverlayMessageText,
            launchAtLoginEnabled: launchAtLoginEnabled ?? self.launchAtLoginEnabled
        )
    }
}
