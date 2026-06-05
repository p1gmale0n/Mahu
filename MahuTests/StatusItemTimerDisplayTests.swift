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

    func testDisablingTimerModeResetsFrozenWidthBackToSquareLength() throws {
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
        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 10))
        controller.install()

        XCTAssertGreaterThan(statusItem.length, NSStatusItem.squareLength)

        controller.setShowsTimerState(false)

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(button.attributedTitle.string, "")
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
        XCTAssertGreaterThan(statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(button.attributedTitle.string, "  02:05")
        XCTAssertEqual(button.attributedTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
    }

    func testTimerModeDegradesPredictablyWhenNoStatusIconIsAvailableAcrossPauseTransitions() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { nil }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 10))

        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        let countdownWidth = statusItem.length
        XCTAssertNil(button.image)
        XCTAssertGreaterThan(statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(button.attributedTitle.string, "  00:10")
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])

        controller.setRemindersPaused(true)

        let pausedButton = try XCTUnwrap(statusItem.button)
        let naturalPausedWidth = ceil(pausedButton.intrinsicContentSize.width)
        XCTAssertNil(pausedButton.image)
        XCTAssertEqual(pausedButton.attributedTitle.string, "  Paused")
        XCTAssertGreaterThan(statusItem.length, countdownWidth)
        XCTAssertGreaterThanOrEqual(statusItem.length, naturalPausedWidth)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
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
        let widthAtTenSeconds = statusItem.length

        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 9))
        let nineSecondTitle = try XCTUnwrap(statusItem.button).attributedTitle
        let widthAtNineSeconds = statusItem.length

        XCTAssertEqual(tenSecondTitle.string, "  00:10")
        XCTAssertEqual(nineSecondTitle.string, "  00:09")
        XCTAssertEqual(tenSecondTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(nineSecondTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(widthAtNineSeconds, widthAtTenSeconds, accuracy: 0.001)
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
        XCTAssertGreaterThan(statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(button.attributedTitle.string, "  00:20")
        XCTAssertEqual(button.attributedTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertTrue(try XCTUnwrap(button.image) === providedIcon)
    }

    func testTimerModeKeepsRestCountdownVisibleWhilePauseStateDimsIconAndUpdatesMenuTitle() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let providedIcon = makeOpaqueStatusIcon()
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { providedIcon }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .rest, remainingSeconds: 20))
        controller.install()
        let normalImageData = try XCTUnwrap(statusItem.button?.image?.tiffRepresentation)

        controller.setRemindersPaused(true)

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertGreaterThan(statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(button.attributedTitle.string, "  00:20")
        XCTAssertEqual(button.attributedTitle.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertEqual(button.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertNotEqual(try XCTUnwrap(button.image?.tiffRepresentation), normalImageData)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
    }

    func testPausedWorkStateExpandsPastNarrowCountdownWidthAndPreservesReadableMenuBarContent() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let providedIcon = makeOpaqueStatusIcon()
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { providedIcon }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.install()

        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 10))

        let countdownButton = try XCTUnwrap(statusItem.button)
        let countdownWidth = statusItem.length
        let countdownImageData = try XCTUnwrap(countdownButton.image?.tiffRepresentation)

        XCTAssertEqual(countdownButton.attributedTitle.string, "  00:10")
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])

        controller.setRemindersPaused(true)

        let pausedButton = try XCTUnwrap(statusItem.button)
        let pausedWidth = statusItem.length
        let naturalPausedWidth = ceil(pausedButton.intrinsicContentSize.width)

        XCTAssertEqual(pausedButton.attributedTitle.string, "  Paused")
        XCTAssertGreaterThan(pausedWidth, countdownWidth, "Paused should expand past the narrower countdown width")
        XCTAssertGreaterThanOrEqual(pausedWidth, naturalPausedWidth)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
        XCTAssertEqual(pausedButton.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertNotEqual(try XCTUnwrap(pausedButton.image?.tiffRepresentation), countdownImageData)
    }

    func testTimerModeKeepsLongestObservedWidthAcrossDigitBoundaryChanges() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 6_000))
        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        let widthAtHundredMinutes = statusItem.length

        XCTAssertEqual(button.attributedTitle.string, "  100:00")

        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 5_999))

        XCTAssertEqual(button.attributedTitle.string, "  99:59")
        XCTAssertEqual(statusItem.length, widthAtHundredMinutes, accuracy: 0.001)
    }

    private func timerDisplayFont() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    private func makeOpaqueStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.labelColor.setFill()
        NSBezierPath(rect: NSRect(x: 2, y: 2, width: 14, height: 14)).fill()
        image.unlockFocus()
        return image
    }
}
