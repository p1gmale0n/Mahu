import Foundation
@testable import Mahu

func makeCurrentUptimeProvider(_ values: [TimeInterval]) -> () -> TimeInterval {
    var remainingValues = values
    var lastValue = values.last ?? 0

    return {
        if let nextValue = remainingValues.first {
            remainingValues.removeFirst()
            lastValue = nextValue
        }

        return lastValue
    }
}

final class CancellationSpy {
    private(set) var cancelCallCount = 0

    func cancel() {
        cancelCallCount += 1
    }
}

final class FakeBreakTimer: BreakTimerControlling {
    private(set) var advanceCalls: [TimeInterval] = []
    private let statesToReturn: [BreakTimer.State]
    private let skipReturnState: BreakTimer.State
    private var currentState: BreakTimer.State
    private var stateIndex = 0

    private(set) var skipBreakCallCount = 0

    init(
        state: BreakTimer.State = .init(phase: .work, remainingSeconds: 0),
        statesToReturn: [BreakTimer.State] = [],
        skipState: BreakTimer.State? = nil
    ) {
        currentState = state
        self.statesToReturn = statesToReturn
        skipReturnState = skipState ?? state
    }

    var state: BreakTimer.State {
        currentState
    }

    func advance(by elapsedSeconds: TimeInterval) -> BreakTimer.State {
        advanceCalls.append(elapsedSeconds)

        if stateIndex < statesToReturn.count {
            currentState = statesToReturn[stateIndex]
            stateIndex += 1
        }

        return currentState
    }

    func skipBreak() -> BreakTimer.State {
        skipBreakCallCount += 1
        currentState = skipReturnState
        return currentState
    }
}

final class FakeStatusItemController: StatusItemControlling {
    private(set) var installCallCount = 0
    private(set) var configureReminderActionsCallCount = 0
    private(set) var remindersPausedUpdates: [Bool] = []
    private(set) var pauseRemindersHandler: (() -> Void)?
    private(set) var resumeRemindersHandler: (() -> Void)?

    func install() {
        installCallCount += 1
    }

    func configureReminderActions(onPause: @escaping () -> Void, onResume: @escaping () -> Void) {
        configureReminderActionsCallCount += 1
        pauseRemindersHandler = onPause
        resumeRemindersHandler = onResume
    }

    func setRemindersPaused(_ paused: Bool) {
        remindersPausedUpdates.append(paused)
    }
}

@MainActor
final class FakeBreakOverlayManager: BreakOverlayManaging {
    enum Event: Equatable {
        case show(TimeInterval)
        case update(TimeInterval)
        case hide
    }

    var hasVisibleOverlayWindows = false {
        didSet {
            guard hasVisibleOverlayWindows != oldValue else {
                return
            }

            onVisibleOverlayWindowsChange?(hasVisibleOverlayWindows)
        }
    }
    var onVisibleOverlayWindowsChange: OverlayVisibilityChangeHandler?
    private(set) var events: [Event] = []
    private(set) var skipHandler: (() -> Void)?
    var showBreakResult = true

    func showBreak(remainingSeconds: TimeInterval, onSkip: @escaping () -> Void) -> Bool {
        events.append(.show(remainingSeconds))
        skipHandler = onSkip
        hasVisibleOverlayWindows = showBreakResult
        return showBreakResult
    }

    func updateRemainingSeconds(_ remainingSeconds: TimeInterval) {
        events.append(.update(remainingSeconds))
    }

    func hideBreak() {
        events.append(.hide)
        skipHandler = nil
        hasVisibleOverlayWindows = false
    }
}
