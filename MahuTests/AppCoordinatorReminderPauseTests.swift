import AppKit
import XCTest
@testable import Mahu

@MainActor
final class AppCoordinatorReminderPauseTests: XCTestCase {
    func testPauseDisablesTimerAdvancementEvenWhileScheduledTicksContinueFiring() throws {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 300)
        )
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([10, 11, 12])

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: currentUptime
        )

        coordinator.start()
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)

        pauseReminders()
        scheduledTick?()
        scheduledTick?()

        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
    }

    func testResumeStartsFreshWorkIntervalFromCurrentRuntimeSettingsSource() throws {
        let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let runtimeEditedConfig = AppConfig(workDurationSeconds: 600, breakDurationSeconds: 45)
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: 295)]
        )
        let resumedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: runtimeEditedConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: 299)]
        )
        var createdConfigs: [AppConfig] = []
        var loadConfigCallCount = 0
        var scheduledTick: (() -> Void)?
        var uptime = 20.0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: {
                defer { loadConfigCallCount += 1 }
                return loadConfigCallCount == 0 ? startupConfig : runtimeEditedConfig
            },
            makeBreakTimer: { config in
                createdConfigs.append(config)
                return createdConfigs.count == 1 ? initialTimer : resumedTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: { uptime }
        )

        coordinator.start()
        uptime = 25
        scheduledTick?()

        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        runtimeSettingsStore.update(runtimeEditedConfig)
        resumeReminders()
        uptime = 26
        scheduledTick?()

        XCTAssertEqual(loadConfigCallCount, 0)
        XCTAssertEqual(createdConfigs, [startupConfig, runtimeEditedConfig])
        XCTAssertEqual(initialTimer.advanceCalls, [5])
        XCTAssertEqual(resumedTimer.advanceCalls, [1])
    }

    func testLongSleepWhileRemindersArePausedKeepsRemindersPausedAndDoesNotShowBreak() throws {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 1)
        )
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
            makeBreakTimer: { _ in fakeTimer },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 200, 201]),
            currentWallClockDate: makeCurrentWallClockDateProvider([
                Date(timeIntervalSinceReferenceDate: 4_000),
                Date(timeIntervalSinceReferenceDate: 4_000 + longSleepResetThresholdSeconds + 1)
            ]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)

        pauseReminders()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        scheduledTick?()

        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true])
        XCTAssertTrue(fakeTimer.advanceCalls.isEmpty)
        XCTAssertTrue(fakeOverlayManager.events.isEmpty)
    }

    func testLongSleepWhilePausedResetsBaselineSoResumeDoesNotConsumeHiddenWorkTime() throws {
        let startupConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 42)
        )
        let resumedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: startupConfig.workDurationSeconds - 1)]
        )
        var createdTimers = 0
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { startupConfig },
            makeBreakTimer: { _ in
                defer { createdTimers += 1 }
                return createdTimers == 0 ? initialTimer : resumedTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([100, 1_000, 1_000, 1_001, 1_002]),
            currentWallClockDate: makeCurrentWallClockDateProvider([
                Date(timeIntervalSinceReferenceDate: 5_000),
                Date(timeIntervalSinceReferenceDate: 5_000 + longSleepResetThresholdSeconds + 10)
            ]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        resumeReminders()
        scheduledTick?()

        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true, false])
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resumedTimer.advanceCalls, [1])
    }

    func testResumeAfterLongSleepWhilePausedStartsFreshWorkIntervalFromCurrentRuntimeSettings() throws {
        let startupConfig = AppConfig(
            workDurationSeconds: 300,
            breakDurationSeconds: 20,
            showStatusItemTimerState: true
        )
        let runtimeEditedConfig = AppConfig(
            workDurationSeconds: 600,
            breakDurationSeconds: 45,
            showStatusItemTimerState: true
        )
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: startupConfig)
        let fakeStatusItemController = FakeStatusItemController()
        let fakeSleepWakeRegistrar = FakeSleepWakeObserverRegistrar()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: 120)
        )
        let resumedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: runtimeEditedConfig.workDurationSeconds),
            statesToReturn: [.init(phase: .work, remainingSeconds: runtimeEditedConfig.workDurationSeconds - 1)]
        )
        var createdConfigs: [AppConfig] = []
        var scheduledTick: (() -> Void)?

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            runtimeSettingsStore: runtimeSettingsStore,
            loadConfig: { startupConfig },
            makeBreakTimer: { config in
                createdConfigs.append(config)
                return createdConfigs.count == 1 ? initialTimer : resumedTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: makeCurrentUptimeProvider([50, 500, 500, 501, 502]),
            currentWallClockDate: makeCurrentWallClockDateProvider([
                Date(timeIntervalSinceReferenceDate: 6_000),
                Date(timeIntervalSinceReferenceDate: 6_000 + longSleepResetThresholdSeconds + 30)
            ]),
            sleepWakeRegistrar: fakeSleepWakeRegistrar.register
        )

        coordinator.start()
        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        runtimeSettingsStore.update(runtimeEditedConfig)
        fakeSleepWakeRegistrar.fireWillSleep()
        fakeSleepWakeRegistrar.fireDidWake()
        resumeReminders()
        scheduledTick?()

        XCTAssertEqual(createdConfigs, [startupConfig, runtimeEditedConfig])
        XCTAssertEqual(initialTimer.advanceCalls, [])
        XCTAssertEqual(resumedTimer.advanceCalls, [1])
        XCTAssertEqual(
            fakeStatusItemController.renderedTimerTexts,
            ["02:00", "Paused", "10:00", "09:59"]
        )
    }

    func testPauseAndResumeUpdateStatusMenuStateExactlyOncePerEffectiveStateChange() throws {
        let fakeStatusItemController = FakeStatusItemController()

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { .default },
            makeBreakTimer: { _ in FakeBreakTimer() },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()

        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        resumeReminders()

        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true, false])
    }

    func testRepeatedPauseAndResumeDuringActiveBreakDoNotResetBreakTimingOrSkipHandler() throws {
        let fakeStatusItemController = FakeStatusItemController()
        let fakeOverlayManager = FakeBreakOverlayManager()
        let fakeTimer = FakeBreakTimer(
            state: .init(phase: .rest, remainingSeconds: 20),
            statesToReturn: [.init(phase: .rest, remainingSeconds: 14)],
            skipState: .init(phase: .work, remainingSeconds: 300)
        )
        var timerCreationCount = 0
        var scheduledTick: (() -> Void)?
        var uptime = 100.0

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: fakeOverlayManager,
            loadConfig: { .default },
            makeBreakTimer: { _ in
                timerCreationCount += 1
                return fakeTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: { uptime }
        )

        coordinator.start()

        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        uptime = 103
        pauseReminders()
        resumeReminders()
        resumeReminders()
        uptime = 106
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 1)
        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true, false])
        XCTAssertEqual(fakeTimer.advanceCalls, [6])
        XCTAssertEqual(
            fakeOverlayManager.events.filter {
                if case .show = $0 {
                    return true
                }
                return false
            }.count,
            1
        )

        let skipHandler = try XCTUnwrap(fakeOverlayManager.skipHandler)
        skipHandler()

        XCTAssertEqual(fakeTimer.skipBreakCallCount, 1)
        XCTAssertTrue(fakeOverlayManager.events.contains(.hide))
    }

    func testRepeatedPauseAndResumeAreIdempotentAndDoNotResetWorkTwice() throws {
        let expectedConfig = AppConfig(workDurationSeconds: 300, breakDurationSeconds: 20)
        let fakeStatusItemController = FakeStatusItemController()
        let initialTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: expectedConfig.workDurationSeconds)
        )
        let resumedTimer = FakeBreakTimer(
            state: .init(phase: .work, remainingSeconds: expectedConfig.workDurationSeconds)
        )
        var timerCreationCount = 0
        var scheduledTick: (() -> Void)?
        let currentUptime = makeCurrentUptimeProvider([40, 42, 42, 42, 43])

        let coordinator = AppCoordinator(
            statusItemController: fakeStatusItemController,
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { expectedConfig },
            makeBreakTimer: { _ in
                defer { timerCreationCount += 1 }
                return timerCreationCount == 0 ? initialTimer : resumedTimer
            },
            scheduleRepeatingTick: { _, tick in
                scheduledTick = tick
                return {}
            },
            currentUptime: currentUptime
        )

        coordinator.start()
        scheduledTick?()

        let pauseReminders = try XCTUnwrap(fakeStatusItemController.pauseRemindersHandler)
        let resumeReminders = try XCTUnwrap(fakeStatusItemController.resumeRemindersHandler)

        pauseReminders()
        pauseReminders()
        resumeReminders()
        resumeReminders()
        scheduledTick?()

        XCTAssertEqual(timerCreationCount, 2)
        XCTAssertEqual(fakeStatusItemController.remindersPausedUpdates, [true, false])
        XCTAssertEqual(initialTimer.advanceCalls, [2])
        XCTAssertEqual(resumedTimer.advanceCalls, [1])
    }

    func testRealPauseResumeMenuItemsDriveCoordinatorAndPreserveExistingStatusIcon() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let providedIcon = NSImage(size: NSSize(width: 18, height: 18))
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { providedIcon }
        )

        let coordinator = AppCoordinator(
            statusItemController: controller,
            overlayManager: FakeBreakOverlayManager(),
            loadConfig: { .default },
            makeBreakTimer: { _ in FakeBreakTimer(state: .init(phase: .work, remainingSeconds: 300)) },
            scheduleRepeatingTick: { _, _ in {} }
        )

        coordinator.start()

        let button = try XCTUnwrap(statusItem.button)
        let initialImage = try XCTUnwrap(button.image)
        XCTAssertTrue(initialImage === providedIcon)
        XCTAssertTrue(initialImage.isTemplate)
        XCTAssertEqual(button.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])

        try invokeMenuItem(named: "Pause Reminders", in: statusItem.menu)

        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
        XCTAssertLessThan(button.alphaValue, 1.0)
        XCTAssertTrue(button.alphaValue >= 0.45)
        XCTAssertTrue(button.alphaValue <= 0.60)
        XCTAssertTrue(try XCTUnwrap(button.image) === initialImage)
        XCTAssertFalse(statusItem.menu?.items.contains(where: { $0.title == "Start Break" }) == true)

        try invokeMenuItem(named: "Resume Reminders", in: statusItem.menu)

        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
        XCTAssertEqual(button.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertTrue(try XCTUnwrap(button.image) === initialImage)
        XCTAssertFalse(statusItem.menu?.items.contains(where: { $0.title == "Start Break" }) == true)
    }

    private func invokeMenuItem(named title: String, in menu: NSMenu?) throws {
        let item = try menuItem(named: title, in: menu)
        let target = try XCTUnwrap(item.target as AnyObject?)
        let action = try XCTUnwrap(item.action)
        _ = target.perform(action, with: item)
    }

    private func menuItem(named title: String, in menu: NSMenu?) throws -> NSMenuItem {
        let menu = try XCTUnwrap(menu)
        return try XCTUnwrap(menu.items.first { $0.title == title })
    }
}
