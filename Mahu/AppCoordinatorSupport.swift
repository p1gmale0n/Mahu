import Foundation

protocol BreakTimerControlling: AnyObject {
    var state: BreakTimer.State { get }

    @discardableResult
    func advance(by elapsedSeconds: TimeInterval) -> BreakTimer.State

    @discardableResult
    func skipBreak() -> BreakTimer.State
}

protocol StatusItemControlling: AnyObject {
    func install()
    func configureReminderActions(onPause: @escaping () -> Void, onResume: @escaping () -> Void)
    func setRemindersPaused(_ paused: Bool)
    func setShowsTimerState(_ showsTimerState: Bool)
    func setStatusDisplayState(_ statusDisplayState: StatusDisplayState)
}

typealias RepeatingTickScheduler = (TimeInterval, @escaping () -> Void) -> () -> Void
typealias CurrentUptimeProvider = () -> TimeInterval
typealias OverlayVisibilityChangeHandler = (Bool) -> Void

@MainActor
protocol BreakOverlayManaging: AnyObject {
    var hasVisibleOverlayWindows: Bool { get }
    var onVisibleOverlayWindowsChange: OverlayVisibilityChangeHandler? { get set }
    @discardableResult
    func showBreak(remainingSeconds: TimeInterval, messageText: String, onSkip: @escaping () -> Void) -> Bool
    func updateRemainingSeconds(_ remainingSeconds: TimeInterval)
    func hideBreak()
}

enum LiveRepeatingScheduler {
    static func schedule(interval: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            action()
        }

        RunLoop.main.add(timer, forMode: .common)

        return {
            timer.invalidate()
        }
    }
}

extension BreakTimer: BreakTimerControlling {
}

extension StatusItemController: StatusItemControlling {
}

@MainActor
extension BreakOverlayManager: BreakOverlayManaging {
}
