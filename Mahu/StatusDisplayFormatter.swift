import Foundation

enum StatusDisplayState: Equatable {
    case active(phase: BreakTimer.Phase, remainingSeconds: TimeInterval)
    case away
    case paused
}

struct StatusDisplayFormatter {
    func string(for state: StatusDisplayState) -> String {
        switch state {
        case let .active(_, remainingSeconds):
            return Self.countdownText(for: remainingSeconds)
        case .away:
            return "Away"
        case .paused:
            return "Paused"
        }
    }

    static func countdownText(for remainingSeconds: TimeInterval) -> String {
        let safeSeconds = AppConfig.safeDisplayWholeSeconds(remainingSeconds)
        let minutes = safeSeconds / 60
        let seconds = safeSeconds % 60
        return String(format: "%02lld:%02lld", minutes, seconds)
    }
}
