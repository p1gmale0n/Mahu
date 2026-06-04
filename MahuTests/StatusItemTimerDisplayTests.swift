import AppKit
import XCTest
@testable import Mahu

@MainActor
final class StatusItemTimerDisplayTests: XCTestCase {
    func testIconOnlyModeKeepsSquareLengthAndExistingImageOnlyContract() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let providedIcon = NSImage(size: NSSize(width: 18, height: 18))
        var providerCallCount = 0
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: {
                providerCallCount += 1
                return providedIcon
            }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})

        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(providerCallCount, 1)
        XCTAssertEqual(statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
    }

    func testIconOnlyModeIgnoresTimerStateUpdatesAfterInstall() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let providedIcon = NSImage(size: NSSize(width: 18, height: 18))
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { providedIcon }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.install()

        controller.setShowsTimerState(false)
        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 125))

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
    }

    func testTimerModeShowsExistingTrayIconPlusFormattedCountdown() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let providedIcon = NSImage(size: NSSize(width: 18, height: 18))
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { providedIcon }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 125))

        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(statusItem.length, NSStatusItem.variableLength)
        XCTAssertEqual(button.title, "02:05")
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
    }

    func testTimerModeCanBeEnabledAfterInstallUsingProductionCallOrder() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let providedIcon = NSImage(size: NSSize(width: 18, height: 18))
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { providedIcon }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.install()

        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .rest, remainingSeconds: 20))

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(statusItem.length, NSStatusItem.variableLength)
        XCTAssertEqual(button.title, "00:20")
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
    }

    func testTimerModeShowsPausedTextWhileKeepingExistingIconAndDimming() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let providedIcon = NSImage(size: NSSize(width: 18, height: 18))
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { providedIcon }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .rest, remainingSeconds: 20))
        controller.install()

        controller.setRemindersPaused(true)

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(statusItem.length, NSStatusItem.variableLength)
        XCTAssertEqual(button.title, "Paused")
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
        XCTAssertLessThan(button.alphaValue, 1.0)
        XCTAssertTrue(button.alphaValue >= 0.45)
        XCTAssertTrue(button.alphaValue <= 0.60)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
    }
}
