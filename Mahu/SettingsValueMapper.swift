import Foundation

@MainActor
enum SettingsValueMapper {
    static let supportedValueNormalizationNotice = "Some timer values loaded from config.json are outside the Settings UI ranges. Mahu is showing the nearest supported values here, but the current runtime and config keep each raw value until you edit that specific control."

    static func workDurationMinutes(from seconds: TimeInterval) -> Int {
        nearestMinutes(from: seconds, range: SettingsViewModel.workDurationMinutesRange)
    }

    static func breakDurationSeconds(from seconds: TimeInterval) -> Int {
        nearestSteppedSeconds(
            from: seconds,
            range: SettingsViewModel.breakDurationSecondsRange,
            step: SettingsViewModel.breakDurationStepSeconds
        )
    }

    static func idleAwayResetMinutes(from seconds: TimeInterval) -> Int {
        nearestMinutes(from: seconds, range: SettingsViewModel.idleAwayMinutesRange)
    }

    static func normalizeWorkDurationMinutes(_ minutes: Int) -> Int {
        clamp(minutes, to: SettingsViewModel.workDurationMinutesRange)
    }

    static func normalizeBreakDurationSeconds(_ seconds: Int) -> Int {
        let clampedSeconds = clamp(seconds, to: SettingsViewModel.breakDurationSecondsRange)
        let roundedToStep = (
            (clampedSeconds + (SettingsViewModel.breakDurationStepSeconds - 1)) /
            SettingsViewModel.breakDurationStepSeconds
        ) * SettingsViewModel.breakDurationStepSeconds
        return min(SettingsViewModel.breakDurationSecondsRange.upperBound, roundedToStep)
    }

    static func normalizeIdleAwayResetMinutes(_ minutes: Int) -> Int {
        clamp(minutes, to: SettingsViewModel.idleAwayMinutesRange)
    }

    static func canonicalUISettings(from settings: AppConfig) -> AppConfig {
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

    static func supportedValueNormalizationNoticeText(
        for settings: AppConfig,
        uiSettings: AppConfig
    ) -> String? {
        settings == uiSettings ? nil : supportedValueNormalizationNotice
    }

    private static func nearestMinutes(
        from seconds: TimeInterval,
        range: ClosedRange<Int>
    ) -> Int {
        guard seconds.isFinite else {
            return range.lowerBound
        }

        let roundedMinutes = nearestWholeMinutes(from: max(0, seconds))
        return clamp(roundedMinutes, to: range)
    }

    private static func nearestSteppedSeconds(
        from seconds: TimeInterval,
        range: ClosedRange<Int>,
        step: Int
    ) -> Int {
        guard seconds.isFinite else {
            return range.lowerBound
        }

        let roundedSteps = (max(0, seconds) / Double(step)).rounded(.toNearestOrAwayFromZero)
        let maximumSafeSteps = Double(Int.max / step)
        guard roundedSteps < maximumSafeSteps else {
            return range.upperBound
        }

        let roundedSeconds = Int(roundedSteps) * step
        return clamp(roundedSeconds, to: range)
    }

    private static func nearestWholeMinutes(from seconds: TimeInterval) -> Int {
        let roundedMinutes = (seconds / 60).rounded(.toNearestOrAwayFromZero)
        guard roundedMinutes < Double(Int.max) else {
            return Int.max
        }

        return Int(roundedMinutes)
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
