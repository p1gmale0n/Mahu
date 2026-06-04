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
        XCTAssertEqual(button.attributedTitle.string, "  02:05")
        XCTAssertEqual(button.attributedTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
    }

    func testTimerModeUsesStableWidthDigitPresentationAcrossCountdownChanges() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.install()

        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 10))
        let tenSecondTitle = try XCTUnwrap(statusItem.button).attributedTitle

        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 9))
        let nineSecondTitle = try XCTUnwrap(statusItem.button).attributedTitle

        XCTAssertEqual(tenSecondTitle.string, "  00:10")
        XCTAssertEqual(nineSecondTitle.string, "  00:09")
        XCTAssertEqual(tenSecondTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(nineSecondTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
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
        XCTAssertEqual(button.attributedTitle.string, "  00:20")
        XCTAssertEqual(button.attributedTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
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
        XCTAssertEqual(button.attributedTitle.string, "  Paused")
        XCTAssertEqual(button.attributedTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
        XCTAssertLessThan(button.alphaValue, 1.0)
        XCTAssertTrue(button.alphaValue >= 0.45)
        XCTAssertTrue(button.alphaValue <= 0.60)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
    }

    private func timerDisplayFont() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }
}
