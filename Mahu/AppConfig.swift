import Foundation

struct AppConfig: Codable, Equatable {
    let workDurationSeconds: TimeInterval
    let breakDurationSeconds: TimeInterval

    static let `default` = AppConfig(workDurationSeconds: 1_200, breakDurationSeconds: 20)
}
