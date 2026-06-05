import AppKit
import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorStatusItemRuntimeVisibilityResetTests: XCTestCase {
    func testRuntimeDurationChangeThatEnablesTimerDisplayUsesRestartedTimerForFreshBaselines() throws {
        let startupConfig = AppConfig(
            workDurationSeconds: 60_000,
            breakDurationSeconds: 20,
            showStatusItemTimerState: false
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 59,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItem = makeStatusItem()
        let statusItemController = makeStatusItemController(statusItem: statusItem)
        let wideVisibleBaselines = makeVisibleBaselines(
            phase: .work,
            remainingSeconds: startupConfig.workDurationSeconds
        )
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
        XCTAssertEqual(statusItemController.timerDisplayBaselines.itemLength, 0, accuracy: 0.001)
        XCTAssertEqual(statusItemController.timerDisplayBaselines.titleSlotWidth, 0, accuracy: 0.001)

        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(try currentTitle(for: statusItem), "  00:59")
        XCTAssertGreaterThan(statusItem.length, NSStatusItem.squareLength)
        XCTAssertLessThan(
            statusItemController.timerDisplayBaselines.titleSlotWidth,
            wideVisibleBaselines.titleSlotWidth
        )
        XCTAssertLessThan(
            statusItemController.timerDisplayBaselines.itemLength,
            wideVisibleBaselines.itemLength
        )
    }

    func testDeferredBreakDurationUpdateClearsWideWorkBaselinesWhenNextBreakStarts() throws {
        let startupConfig = AppConfig(
            workDurationSeconds: 60_000,
            breakDurationSeconds: 3_600,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 60_000,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItem = makeStatusItem()
        let statusItemController = makeStatusItemController(statusItem: statusItem)
        let wideVisibleBaselines = makeVisibleBaselines(
            phase: .work,
            remainingSeconds: startupConfig.workDurationSeconds
        )
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds)]
        )
        let deferredRestTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .rest, remainingSeconds: updatedConfig.breakDurationSeconds)]
        )
        var createdTimers = 0
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : deferredRestTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([10, 11])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(try currentTitle(for: statusItem), "  1000:00")

        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(try currentTitle(for: statusItem), "  00:20")
        XCTAssertLessThan(
            statusItemController.timerDisplayBaselines.titleSlotWidth,
            wideVisibleBaselines.titleSlotWidth
        )
        XCTAssertLessThan(
            statusItemController.timerDisplayBaselines.itemLength,
            wideVisibleBaselines.itemLength
        )
    }

    func testDeferredWorkDurationUpdateClearsWideRestBaselinesWhenBreakEnds() throws {
        let startupConfig = AppConfig(
            workDurationSeconds: 3_600,
            breakDurationSeconds: 60_000,
            showStatusItemTimerState: true
        )
        let updatedConfig = AppConfig(
            workDurationSeconds: 59,
            breakDurationSeconds: 60_000,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let statusItem = makeStatusItem()
        let statusItemController = makeStatusItemController(statusItem: statusItem)
        let wideVisibleBaselines = makeVisibleBaselines(
            phase: .rest,
            remainingSeconds: startupConfig.breakDurationSeconds
        )
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: startupConfig.breakDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds)]
        )
        let deferredWorkTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: updatedConfig.workDurationSeconds)
        )
        var createdTimers = 0
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: statusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : deferredWorkTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([20, 21, 22])
        )

        coordinator.start()
        runtimeSettingsStore.update(updatedConfig)

        XCTAssertEqual(try currentTitle(for: statusItem), "  1000:00")

        scheduledTick?()

        XCTAssertEqual(createdTimers, 2)
        XCTAssertEqual(try currentTitle(for: statusItem), "  00:59")
        XCTAssertLessThan(
            statusItemController.timerDisplayBaselines.titleSlotWidth,
            wideVisibleBaselines.titleSlotWidth
        )
        XCTAssertLessThan(
            statusItemController.timerDisplayBaselines.itemLength,
            wideVisibleBaselines.itemLength
        )
    }

    private func makeVisibleBaselines(
        phase: BreakTimer.Phase,
        remainingSeconds: TimeInterval
    ) -> (itemLength: CGFloat, titleSlotWidth: CGFloat) {
        let statusItem = makeStatusItem()
        let controller = makeStatusItemController(statusItem: statusItem)
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: phase, remainingSeconds: remainingSeconds))
        controller.install()
        return controller.timerDisplayBaselines
    }

    private func makeStatusItem() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        addTeardownBlock {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        return statusItem
    }

    private func makeStatusItemController(statusItem: NSStatusItem) -> StatusItemController {
        StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
    }

    private func currentTitle(for statusItem: NSStatusItem) throws -> String {
        let rawTitle = try XCTUnwrap(statusItem.button?.attributedTitle.string)
        return rawTitle.hasSuffix("\t") ? String(rawTitle.dropLast()) : rawTitle
    }
}
