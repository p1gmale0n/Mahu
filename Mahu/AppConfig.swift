import Foundation

struct AppConfig: Codable, Equatable {
    static let minimumSupportedDurationSeconds: TimeInterval = 1
    static let maximumSupportedDurationSeconds: TimeInterval = 9_007_199_254_740_992
    static let subsecondPrecisionThresholdSeconds: TimeInterval = 4_503_599_627_370_496
    private static let maximumDisplayableWholeSeconds: TimeInterval = TimeInterval(Int64.max)
    static let defaultBreakOverlayMessageText = "Время отвлечься"
    static let defaultIdleAwayResetThresholdSeconds: TimeInterval = 300

    let workDurationSeconds: TimeInterval
    let breakDurationSeconds: TimeInterval
    let idleAwayResetEnabled: Bool
    let idleAwayResetThresholdSeconds: TimeInterval
    let showStatusItemTimerState: Bool
    let breakOverlayMessageText: String
    let launchAtLoginEnabled: Bool

    static let `default` = AppConfig(
        workDurationSeconds: 1_200,
        breakDurationSeconds: 20,
        idleAwayResetEnabled: false,
        idleAwayResetThresholdSeconds: defaultIdleAwayResetThresholdSeconds,
        showStatusItemTimerState: false,
        breakOverlayMessageText: defaultBreakOverlayMessageText,
        launchAtLoginEnabled: false
    )

    init(
        workDurationSeconds: TimeInterval,
        breakDurationSeconds: TimeInterval,
        idleAwayResetEnabled: Bool = false,
        idleAwayResetThresholdSeconds: TimeInterval = AppConfig.defaultIdleAwayResetThresholdSeconds,
        showStatusItemTimerState: Bool = false,
        breakOverlayMessageText: String = AppConfig.defaultBreakOverlayMessageText,
        launchAtLoginEnabled: Bool = false
    ) {
        self.workDurationSeconds = workDurationSeconds
        self.breakDurationSeconds = breakDurationSeconds
        self.idleAwayResetEnabled = idleAwayResetEnabled
        self.idleAwayResetThresholdSeconds = idleAwayResetThresholdSeconds
        self.showStatusItemTimerState = showStatusItemTimerState
        self.breakOverlayMessageText = Self.normalizedBreakOverlayMessageText(breakOverlayMessageText)
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    var hasSupportedDurations: Bool {
        Self.isSupportedDuration(workDurationSeconds) &&
            Self.isSupportedDuration(breakDurationSeconds)
    }

    var hasSupportedIdleAwayResetThreshold: Bool {
        Self.isSupportedIdleAwayResetThreshold(idleAwayResetThresholdSeconds)
    }

    var hasSupportedSettings: Bool {
        hasSupportedDurations && hasSupportedIdleAwayResetThreshold
    }

    static func safeDisplayWholeSeconds(_ duration: TimeInterval) -> Int64 {
        guard duration.isFinite else {
            return 0
        }

        let roundedDuration = max(0, duration).rounded(.up)
        guard roundedDuration < maximumDisplayableWholeSeconds else {
            return Int64.max
        }

        return Int64(roundedDuration)
    }

    private static func isSupportedDuration(_ duration: TimeInterval) -> Bool {
        duration.isFinite &&
            duration >= minimumSupportedDurationSeconds &&
            duration <= maximumSupportedDurationSeconds
    }

    private static func isSupportedIdleAwayResetThreshold(_ duration: TimeInterval) -> Bool {
        duration.isFinite && duration > 0
    }

    static func normalizedBreakOverlayMessageText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultBreakOverlayMessageText
            : text
    }

    private enum CodingKeys: String, CodingKey {
        case workDurationSeconds
        case breakDurationSeconds
        case idleAwayResetEnabled
        case idleAwayResetThresholdSeconds
        case showStatusItemTimerState
        case breakOverlayMessageText
        case launchAtLoginEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workDurationSeconds = try container.decode(TimeInterval.self, forKey: .workDurationSeconds)
        breakDurationSeconds = try container.decode(TimeInterval.self, forKey: .breakDurationSeconds)
        if container.contains(.idleAwayResetEnabled) {
            idleAwayResetEnabled = try container.decode(Bool.self, forKey: .idleAwayResetEnabled)
        } else {
            idleAwayResetEnabled = false
        }

        if container.contains(.idleAwayResetThresholdSeconds) {
            let threshold = try container.decode(TimeInterval.self, forKey: .idleAwayResetThresholdSeconds)
            guard Self.isSupportedIdleAwayResetThreshold(threshold) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .idleAwayResetThresholdSeconds,
                    in: container,
                    debugDescription: "idleAwayResetThresholdSeconds must be a positive finite number."
                )
            }

            idleAwayResetThresholdSeconds = threshold
        } else {
            idleAwayResetThresholdSeconds = Self.defaultIdleAwayResetThresholdSeconds
        }

        if container.contains(.showStatusItemTimerState) {
            showStatusItemTimerState = try container.decode(Bool.self, forKey: .showStatusItemTimerState)
        } else {
            showStatusItemTimerState = false
        }

        if container.contains(.breakOverlayMessageText) {
            breakOverlayMessageText = Self.normalizedBreakOverlayMessageText(
                try container.decode(String.self, forKey: .breakOverlayMessageText)
            )
        } else {
            breakOverlayMessageText = Self.defaultBreakOverlayMessageText
        }

        if container.contains(.launchAtLoginEnabled) {
            launchAtLoginEnabled = try container.decode(Bool.self, forKey: .launchAtLoginEnabled)
        } else {
            launchAtLoginEnabled = false
        }
    }
}
