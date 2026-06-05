import AppKit
import XCTest
@testable import Mahu

@MainActor
final class StatusItemBehaviorRegressionTests: XCTestCase {
    func testPausedWorkStateKeepsPausedVisibleWhileOnlyIconIsDimmed() throws {
        let statusItem = makeStatusItem()
        let providedIcon = makeOpaqueStatusIcon()
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { providedIcon }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 10))
        controller.install()

        let countdownImageData = try XCTUnwrap(statusItem.button?.image?.tiffRepresentation)

        controller.setRemindersPaused(true)

        let button = try XCTUnwrap(statusItem.button)
        let pausedIntrinsicWidth = ceil(button.intrinsicContentSize.width)

        XCTAssertEqual(visibleTimerTitle(from: button.attributedTitle), "  Paused")
        XCTAssertGreaterThanOrEqual(statusItem.length, pausedIntrinsicWidth)
        XCTAssertEqual(button.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertNotEqual(try XCTUnwrap(button.image?.tiffRepresentation), countdownImageData)
    }

    func testRealPauseResumeMenuActionsPreserveStableLayoutAndMenuTitles() throws {
        let statusItem = makeStatusItem()

        var controller: StatusItemController!
        controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(
            onPause: { controller.setRemindersPaused(true) },
            onResume: { controller.setRemindersPaused(false) }
        )
        controller.setShowsTimerState(true)
        controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 300))
        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        let activeWidth = statusItem.length
        XCTAssertEqual(visibleTimerTitle(from: button.attributedTitle), "  05:00")
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])

        try invokeMenuItem(named: "Pause Reminders", in: statusItem.menu)

        let pausedWidth = statusItem.length
        XCTAssertEqual(visibleTimerTitle(from: button.attributedTitle), "  Paused")
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
        XCTAssertEqual(pausedWidth, activeWidth, accuracy: 0.001)

        try invokeMenuItem(named: "Resume Reminders", in: statusItem.menu)

        XCTAssertEqual(visibleTimerTitle(from: button.attributedTitle), "  05:00")
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
        XCTAssertEqual(statusItem.length, activeWidth, accuracy: 0.001)
    }

    func testTimerModeNoIconFallbackKeepsStableTitleSlotAcrossPauseTransitions() throws {
        let statusItem = makeStatusItem()
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
        let activeWidth = statusItem.length
        XCTAssertNil(button.image)
        XCTAssertEqual(visibleTimerTitle(from: button.attributedTitle), "  00:10")
        XCTAssertEqual(button.imagePosition, .imageLeading)

        controller.setRemindersPaused(true)

        XCTAssertNil(button.image)
        XCTAssertEqual(visibleTimerTitle(from: button.attributedTitle), "  Paused")
        XCTAssertEqual(statusItem.length, activeWidth, accuracy: 0.001)

        controller.setRemindersPaused(false)

        XCTAssertNil(button.image)
        XCTAssertEqual(visibleTimerTitle(from: button.attributedTitle), "  00:10")
        XCTAssertEqual(statusItem.length, activeWidth, accuracy: 0.001)
    }

    func testDefaultIconOnlyModeKeepsSquareLengthAndEmptyTitle() throws {
        let statusItem = makeStatusItem()
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})

        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(visibleTimerTitle(from: button.attributedTitle), "")
        XCTAssertEqual(button.imagePosition, .imageOnly)
    }

    private func makeStatusItem() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        addTeardownBlock {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        return statusItem
    }

    private func invokeMenuItem(named title: String, in menu: NSMenu?) throws {
        let menu = try XCTUnwrap(menu)
        let item = try XCTUnwrap(menu.items.first { $0.title == title })
        let target = try XCTUnwrap(item.target as AnyObject?)
        let action = try XCTUnwrap(item.action)
        _ = target.perform(action, with: item)
    }

    private func makeOpaqueStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.labelColor.setFill()
        NSBezierPath(rect: NSRect(x: 2, y: 2, width: 14, height: 14)).fill()
        image.unlockFocus()
        return image
    }

    private func visibleTimerTitle(from attributedTitle: NSAttributedString) -> String {
        let rawTitle = attributedTitle.string

        if rawTitle.hasSuffix("\t") {
            return String(rawTitle.dropLast())
        }

        return rawTitle
    }
}
