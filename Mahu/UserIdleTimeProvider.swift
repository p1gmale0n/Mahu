import CoreGraphics
import Foundation

private let anyInputEventType = CGEventType(rawValue: UInt32.max)!

protocol UserIdleTimeProviding {
    func currentIdleDurationSeconds() -> TimeInterval
}

private struct ZeroUserIdleTimeProvider: UserIdleTimeProviding {
    func currentIdleDurationSeconds() -> TimeInterval {
        0
    }
}

extension UserIdleTimeProviding {
    func safeCurrentIdleDurationSeconds() -> TimeInterval {
        normalizedIdleDurationSeconds(currentIdleDurationSeconds())
    }
}

func normalizedIdleDurationSeconds(_ idleDurationSeconds: TimeInterval) -> TimeInterval {
    guard idleDurationSeconds.isFinite, idleDurationSeconds >= 0 else {
        return 0
    }

    return idleDurationSeconds
}

func makeDefaultUserIdleTimeProvider(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    liveProviderFactory: () -> UserIdleTimeProviding = { LiveUserIdleTimeProvider() }
) -> UserIdleTimeProviding {
    if AppRuntime.isRunningTests(environment: environment) {
        return ZeroUserIdleTimeProvider()
    }

    return liveProviderFactory()
}

struct LiveUserIdleTimeProvider: UserIdleTimeProviding {
    private let eventSourceStateID: CGEventSourceStateID
    private let eventType: CGEventType
    private let currentIdleSecondsSource: (CGEventSourceStateID, CGEventType) -> TimeInterval

    init(
        eventSourceStateID: CGEventSourceStateID = .hidSystemState,
        eventType: CGEventType = anyInputEventType,
        currentIdleSecondsSource: @escaping (CGEventSourceStateID, CGEventType) -> TimeInterval = CGEventSource.secondsSinceLastEventType
    ) {
        self.eventSourceStateID = eventSourceStateID
        self.eventType = eventType
        self.currentIdleSecondsSource = currentIdleSecondsSource
    }

    func currentIdleDurationSeconds() -> TimeInterval {
        currentIdleSecondsSource(eventSourceStateID, eventType)
    }
}
