import Foundation

struct AppConfig: Codable, Equatable {
    static let minimumSupportedDurationSeconds: TimeInterval = 1
    static let maximumSupportedDurationSeconds: TimeInterval = 9_007_199_254_740_992
    static let subsecondPrecisionThresholdSeconds: TimeInterval = 4_503_599_627_370_496
    private static let maximumDisplayableWholeSeconds: TimeInterval = TimeInterval(Int64.max)

    let workDurationSeconds: TimeInterval
    let breakDurationSeconds: TimeInterval
    let showStatusItemTimerState: Bool

    static let `default` = AppConfig(
        workDurationSeconds: 1_200,
        breakDurationSeconds: 20,
        showStatusItemTimerState: false
    )

    init(
        workDurationSeconds: TimeInterval,
        breakDurationSeconds: TimeInterval,
        showStatusItemTimerState: Bool = false
    ) {
        self.workDurationSeconds = workDurationSeconds
        self.breakDurationSeconds = breakDurationSeconds
        self.showStatusItemTimerState = showStatusItemTimerState
    }

    var hasSupportedDurations: Bool {
        Self.isSupportedDuration(workDurationSeconds) &&
            Self.isSupportedDuration(breakDurationSeconds)
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

    private enum CodingKeys: String, CodingKey {
        case workDurationSeconds
        case breakDurationSeconds
        case showStatusItemTimerState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workDurationSeconds = try container.decode(TimeInterval.self, forKey: .workDurationSeconds)
        breakDurationSeconds = try container.decode(TimeInterval.self, forKey: .breakDurationSeconds)
        if container.contains(.showStatusItemTimerState) {
            showStatusItemTimerState = try container.decode(Bool.self, forKey: .showStatusItemTimerState)
        } else {
            showStatusItemTimerState = false
        }
    }
}
