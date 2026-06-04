import Foundation

final class BreakTimer {
    enum Phase: Equatable {
        case work
        case rest
    }

    struct State: Equatable {
        let phase: Phase
        let remainingSeconds: TimeInterval
    }

    private let workDurationSeconds: TimeInterval
    private let breakDurationSeconds: TimeInterval

    private(set) var state: State

    convenience init(config: AppConfig = .default) {
        self.init(
            workDurationSeconds: config.workDurationSeconds,
            breakDurationSeconds: config.breakDurationSeconds
        )
    }

    init(workDurationSeconds: TimeInterval, breakDurationSeconds: TimeInterval) {
        self.workDurationSeconds = max(0, workDurationSeconds)
        self.breakDurationSeconds = max(0, breakDurationSeconds)
        state = State(phase: .work, remainingSeconds: max(0, workDurationSeconds))
    }

    @discardableResult
    func advance(by elapsedSeconds: TimeInterval) -> State {
        guard collapseZeroLengthPhases() else {
            return state
        }

        guard elapsedSeconds.isFinite, elapsedSeconds > 0 else {
            return state
        }

        var remainingElapsed = elapsedSeconds

        while remainingElapsed > 0 {
            if state.remainingSeconds > remainingElapsed {
                state = State(
                    phase: state.phase,
                    remainingSeconds: state.remainingSeconds - remainingElapsed
                )
                remainingElapsed = 0
                continue
            }

            remainingElapsed -= state.remainingSeconds
            transitionToNextPhase()

            guard collapseZeroLengthPhases() else {
                break
            }
        }

        return state
    }

    @discardableResult
    func skipBreak() -> State {
        guard state.phase == .rest else {
            return state
        }

        state = State(phase: .work, remainingSeconds: workDurationSeconds)
        return state
    }

    private func transitionToNextPhase() {
        switch state.phase {
        case .work:
            state = State(phase: .rest, remainingSeconds: breakDurationSeconds)
        case .rest:
            state = State(phase: .work, remainingSeconds: workDurationSeconds)
        }
    }

    private func collapseZeroLengthPhases() -> Bool {
        guard workDurationSeconds > 0 || breakDurationSeconds > 0 else {
            state = State(phase: .work, remainingSeconds: 0)
            return false
        }

        while state.remainingSeconds == 0 {
            transitionToNextPhase()
        }

        return true
    }
}
