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
}

typealias RepeatingTickScheduler = (TimeInterval, @escaping () -> Void) -> () -> Void
typealias CurrentUptimeProvider = () -> TimeInterval

@MainActor
protocol BreakOverlayManaging: AnyObject {
    @discardableResult
    func showBreak(remainingSeconds: TimeInterval, onSkip: @escaping () -> Void) -> Bool
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

@MainActor
final class AppCoordinator {
    private let statusItemController: StatusItemControlling
    private let overlayManager: BreakOverlayManaging
    private let loadConfig: () -> AppConfig
    private let makeBreakTimer: (AppConfig) -> BreakTimerControlling
    private let scheduleRepeatingTick: RepeatingTickScheduler
    private let currentUptime: CurrentUptimeProvider

    private var cancelTick: (() -> Void)?
    private var breakTimer: BreakTimerControlling?
    private var isShowingBreak = false
    private var lastTickUptime: TimeInterval?

    init(
        statusItemController: StatusItemControlling? = nil,
        overlayManager: BreakOverlayManaging? = nil,
        loadConfig: @escaping () -> AppConfig = { ConfigStore().load() },
        makeBreakTimer: @escaping (AppConfig) -> BreakTimerControlling = { BreakTimer(config: $0) },
        scheduleRepeatingTick: @escaping RepeatingTickScheduler = LiveRepeatingScheduler.schedule,
        currentUptime: @escaping CurrentUptimeProvider = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.statusItemController = statusItemController ?? StatusItemController()
        self.overlayManager = overlayManager ?? BreakOverlayManager()
        self.loadConfig = loadConfig
        self.makeBreakTimer = makeBreakTimer
        self.scheduleRepeatingTick = scheduleRepeatingTick
        self.currentUptime = currentUptime
    }

    func start() {
        guard cancelTick == nil else {
            return
        }

        statusItemController.install()

        let config = loadConfig()
        let breakTimer = makeBreakTimer(config)
        self.breakTimer = breakTimer
        lastTickUptime = currentUptime()
        handle(state: breakTimer.state)
        cancelTick = scheduleRepeatingTick(1) { [weak self] in
            self?.advanceTimer()
        }
    }

    private func advanceTimer() {
        guard let breakTimer, let lastTickUptime else {
            return
        }

        let now = currentUptime()
        let elapsedSeconds = max(0, now - lastTickUptime)
        self.lastTickUptime = now

        if breakTimer.state.phase == .rest, isShowingBreak == false {
            handle(state: breakTimer.state)
            return
        }

        guard elapsedSeconds > 0 else {
            return
        }

        let elapsedToConsume = elapsedToConsume(
            for: breakTimer.state,
            elapsedSeconds: elapsedSeconds
        )
        let state = breakTimer.advance(by: elapsedToConsume)
        handle(state: state)
    }

    private func elapsedToConsume(
        for state: BreakTimer.State,
        elapsedSeconds: TimeInterval
    ) -> TimeInterval {
        guard state.phase == .work else {
            return elapsedSeconds
        }

        guard state.remainingSeconds > 0 else {
            return 0
        }

        return min(elapsedSeconds, state.remainingSeconds)
    }

    private func handle(state: BreakTimer.State) {
        switch state.phase {
        case .work:
            if isShowingBreak {
                overlayManager.hideBreak()
                isShowingBreak = false
            }
        case .rest:
            if isShowingBreak {
                overlayManager.updateRemainingSeconds(state.remainingSeconds)
            } else {
                isShowingBreak = overlayManager.showBreak(remainingSeconds: state.remainingSeconds) { [weak self] in
                    self?.skipBreak()
                }
            }
        }
    }

    private func skipBreak() {
        guard let breakTimer else {
            return
        }

        let state = breakTimer.skipBreak()
        lastTickUptime = currentUptime()
        handle(state: state)
    }

    deinit {
        cancelTick?()
    }
}

extension BreakTimer: BreakTimerControlling {
}

extension StatusItemController: StatusItemControlling {
}

@MainActor
extension BreakOverlayManager: BreakOverlayManaging {
}
