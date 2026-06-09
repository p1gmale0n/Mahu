import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorStatusItemRuntimeResetTests: XCTestCase {
    func testRuntimeDurationChangeClearsTimerDisplayBaselinesBeforeRenderingShorterTimerText() {
        let startupConfig = AppConfig(
            workDurationSeconds: 60_000,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 59,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = SequencingStatusItemControllerSpy()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        let restartedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds)
        )
        var createdTimers = 0

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : restartedTimer
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(statusItemController.clearTimerDisplayBaselinesCallCount, 1)
        XCTAssertEqual(statusItemController.resetTimerDisplayBaselinesCallCount, 0)
        XCTAssertEqual(
            statusItemController.events,
            [
                .setShowsTimerState(true),
                .render("1000:00"),
                .clearTimerDisplayBaselines,
                .render("00:59")
            ]
        )
    }

    func testRuntimeNonDurationChangeDoesNotResetTimerDisplayBaselines() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Initial"
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true,
            breakOverlayMessageText: "Updated"
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = SequencingStatusItemControllerSpy()

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                FakeBreakTimer(state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds))
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(statusItemController.clearTimerDisplayBaselinesCallCount, 0)
        XCTAssertEqual(statusItemController.resetTimerDisplayBaselinesCallCount, 0)
        XCTAssertEqual(
            statusItemController.events,
            [
                .setShowsTimerState(true),
                .render("05:00")
            ]
        )
    }

    func testPausedWorkDurationChangeRecomputesVisiblePausedTitleWithoutRestartingTimer() throws {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 59,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = SequencingStatusItemControllerSpy()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)
        )
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return initialTimer
            },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()
        try XCTUnwrap(statusItemController.pauseRemindersHandler)()
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(statusItemController.clearTimerDisplayBaselinesCallCount, 0)
        XCTAssertEqual(statusItemController.resetTimerDisplayBaselinesCallCount, 1)
        XCTAssertEqual(
            statusItemController.events,
            [
                .setShowsTimerState(true),
                .render("05:00"),
                .setRemindersPaused(true),
                .render("Paused"),
                .resetTimerDisplayBaselines("Paused"),
                .render("Paused")
            ]
        )
    }

    func testActiveRestDurationChangeDefersTimerDisplayBaselineResetUntilBreakEnds() {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItemController = SequencingStatusItemControllerSpy()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds)
        )
        var timerCreationCount = 0

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return initialTimer
            },
            scheduleRepeatingTick: { _, _ in {} },
            currentUptime: makeCurrentUptimeProvider([20, 21])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(statusItemController.clearTimerDisplayBaselinesCallCount, 0)
        XCTAssertEqual(statusItemController.resetTimerDisplayBaselinesCallCount, 0)
        XCTAssertEqual(
            statusItemController.events,
            [
                .setShowsTimerState(true),
                .render("00:20")
            ]
        )
    }
}

final class SequencingStatusItemControllerSpy: StatusItemControlling {
    enum Event: Equatable {
        case setShowsTimerState(Bool)
        case setRemindersPaused(Bool)
        case render(String)
        case clearTimerDisplayBaselines
        case resetTimerDisplayBaselines(String)
    }

    private let statusDisplayFormatter = StatusDisplayFormatter()

    private(set) var events: [Event] = []
    private(set) var pauseRemindersHandler: (() -> Void)?
    private(set) var resumeRemindersHandler: (() -> Void)?
    private(set) var clearTimerDisplayBaselinesCallCount = 0
    private(set) var resetTimerDisplayBaselinesCallCount = 0

    private var remindersPaused = false
    private var showsTimerState = false
    private var currentStatusDisplayState: StatusDisplayState?

    func install() {}

    func configureReminderActions(onPause: @escaping () -> Void, onResume: @escaping () -> Void) {
        pauseRemindersHandler = onPause
        resumeRemindersHandler = onResume
    }

    func setRemindersPaused(_ paused: Bool) {
        remindersPaused = paused
        events.append(.setRemindersPaused(paused))
        recordRenderedTimerTextIfNeeded()
    }

    func setShowsTimerState(_ showsTimerState: Bool) {
        guard self.showsTimerState != showsTimerState else {
            return
        }

        self.showsTimerState = showsTimerState
        events.append(.setShowsTimerState(showsTimerState))
        recordRenderedTimerTextIfNeeded()
    }

    func clearTimerDisplayBaselines() {
        clearTimerDisplayBaselinesCallCount += 1
        events.append(.clearTimerDisplayBaselines)
    }

    func resetTimerDisplayBaselines() {
        resetTimerDisplayBaselinesCallCount += 1
        events.append(.resetTimerDisplayBaselines(currentRenderedTimerText() ?? ""))
        recordRenderedTimerTextIfNeeded()
    }

    func setStatusDisplayState(_ statusDisplayState: StatusDisplayState) {
        currentStatusDisplayState = statusDisplayState
        recordRenderedTimerTextIfNeeded()
    }

    private func recordRenderedTimerTextIfNeeded() {
        guard showsTimerState, let text = currentRenderedTimerText() else {
            return
        }

        events.append(.render(text))
    }

    private func currentRenderedTimerText() -> String? {
        guard let currentStatusDisplayState else {
            return remindersPaused ? statusDisplayFormatter.string(for: .paused) : nil
        }

        switch currentStatusDisplayState {
        case let .active(phase, remainingSeconds):
            if remindersPaused, phase == .work {
                return statusDisplayFormatter.string(for: .paused)
            }

            return statusDisplayFormatter.string(
                for: .active(phase: phase, remainingSeconds: remainingSeconds)
            )
        case .away:
            return statusDisplayFormatter.string(for: .away)
        case .paused:
            return statusDisplayFormatter.string(for: .paused)
        }
    }
}
