import AppKit
import XCTest
@testable import Mahu

@MainActor
final class StatusItemMenuAcceptanceTests: XCTestCase {
    func testStatusMenuShowsReminderToggleWithoutManualStartBreakAction() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )

        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.install()

        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
        XCTAssertFalse(statusItem.menu?.items.contains(where: { $0.title == "Start Break" }) == true)

        controller.setRemindersPaused(true)

        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
        XCTAssertFalse(statusItem.menu?.items.contains(where: { $0.title == "Start Break" }) == true)
    }

    func testConfiguredReminderActionsDriveRealStatusMenuItems() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        var pauseInvocationCount = 0
        var resumeInvocationCount = 0
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )

        controller.configureReminderActions(
            onPause: { pauseInvocationCount += 1 },
            onResume: { resumeInvocationCount += 1 }
        )
        controller.install()

        try invokeMenuItem(named: "Pause Reminders", in: statusItem.menu)
        controller.setRemindersPaused(true)
        try invokeMenuItem(named: "Resume Reminders", in: statusItem.menu)

        XCTAssertEqual(pauseInvocationCount, 1)
        XCTAssertEqual(resumeInvocationCount, 1)
    }

    func testConfiguringReminderActionsAfterInstallEnablesReminderToggle() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        var pauseInvocationCount = 0
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )

        controller.install()
        XCTAssertFalse(try menuItem(named: "Pause Reminders", in: statusItem.menu).isEnabled)

        controller.configureReminderActions(
            onPause: { pauseInvocationCount += 1 },
            onResume: {}
        )

        XCTAssertTrue(try menuItem(named: "Pause Reminders", in: statusItem.menu).isEnabled)

        try invokeMenuItem(named: "Pause Reminders", in: statusItem.menu)
        XCTAssertEqual(pauseInvocationCount, 1)
    }

    func testFreshStatusItemControllerStartsEnabledAfterPreviousControllerWasPaused() {
        let firstStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(firstStatusItem) }
        let secondStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(secondStatusItem) }

        let firstController = StatusItemController(
            statusItem: firstStatusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        firstController.configureReminderActions(onPause: {}, onResume: {})
        firstController.install()
        firstController.setRemindersPaused(true)

        let secondController = StatusItemController(
            statusItem: secondStatusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        secondController.configureReminderActions(onPause: {}, onResume: {})
        secondController.install()

        XCTAssertEqual(firstStatusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
        XCTAssertEqual(secondStatusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
    }

    func testPauseAndResumeTransitionsKeepMenuContractAndSyncIconOpacity() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(button.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
        XCTAssertFalse(statusItem.menu?.items.contains(where: { $0.title == "Start Break" }) == true)

        controller.setRemindersPaused(true)

        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
        XCTAssertLessThan(button.alphaValue, 1.0)
        XCTAssertTrue(button.alphaValue >= 0.45)
        XCTAssertTrue(button.alphaValue <= 0.60)
        XCTAssertFalse(statusItem.menu?.items.contains(where: { $0.title == "Start Break" }) == true)

        controller.setRemindersPaused(false)

        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
        XCTAssertEqual(button.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertFalse(statusItem.menu?.items.contains(where: { $0.title == "Start Break" }) == true)
    }

    func testTimerModePauseAndResumeTransitionsKeepMenuTitlesCorrect() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 300))
        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(button.attributedTitle.string, "  05:00")
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])

        controller.setRemindersPaused(true)

        XCTAssertEqual(button.attributedTitle.string, "  Paused")
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])

        controller.setRemindersPaused(false)

        XCTAssertEqual(button.attributedTitle.string, "  05:00")
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
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
