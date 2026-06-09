import Foundation

let longSleepResetThresholdSeconds: TimeInterval = 300

enum WakeReconciliationAction: Equatable {
    case none
    case preservePausedWork
    case resetActiveWork
    case resetAfterActiveRest
}

enum IdleAwayEpisodeAction: Equatable {
    case none
    case suppressElapsedOnly
    case suppressElapsedAndReset(WakeReconciliationAction)
}

struct IdleAwayEpisodePolicy {
    private var hasAppliedResetInCurrentIdleEpisode = false

    mutating func reset() {
        hasAppliedResetInCurrentIdleEpisode = false
    }

    mutating func action(
        idleDurationSeconds: TimeInterval,
        currentState: BreakTimer.State?,
        remindersPaused: Bool,
        longIdleThresholdSeconds: TimeInterval = longSleepResetThresholdSeconds
    ) -> IdleAwayEpisodeAction {
        let normalizedIdleDuration = normalizedIdleDurationSeconds(idleDurationSeconds)
        guard normalizedIdleDuration >= longIdleThresholdSeconds else {
            hasAppliedResetInCurrentIdleEpisode = false
            return .none
        }

        guard hasAppliedResetInCurrentIdleEpisode == false else {
            return .suppressElapsedOnly
        }

        hasAppliedResetInCurrentIdleEpisode = true
        return .suppressElapsedAndReset(
            longAwayReconciliationAction(
                currentState: currentState,
                remindersPaused: remindersPaused
            )
        )
    }
}

func longAwayReconciliationAction(
    currentState: BreakTimer.State?,
    remindersPaused: Bool
) -> WakeReconciliationAction {
    guard let currentState else {
        return .none
    }

    switch currentState.phase {
    case .work:
        return remindersPaused ? .preservePausedWork : .resetActiveWork
    case .rest:
        return .resetAfterActiveRest
    }
}

func wakeReconciliationAction(
    sleepStartedAt: TimeInterval?,
    wokeAt: TimeInterval,
    currentState: BreakTimer.State?,
    remindersPaused: Bool,
    longSleepThresholdSeconds: TimeInterval = longSleepResetThresholdSeconds
) -> WakeReconciliationAction {
    guard let sleepStartedAt else {
        return .none
    }

    guard max(0, wokeAt - sleepStartedAt) >= longSleepThresholdSeconds else {
        return .none
    }

    return longAwayReconciliationAction(
        currentState: currentState,
        remindersPaused: remindersPaused
    )
}
