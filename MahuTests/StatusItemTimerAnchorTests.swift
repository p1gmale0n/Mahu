import AppKit
import XCTest
@testable import Mahu

@MainActor
final class StatusItemTimerAnchorTests: XCTestCase {
    func testWorkPauseAndResumeKeepTimerTitleSlotWidthStableAcrossVisibleTextChanges() throws {
        let harness = makeHarness()

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 125))
        let activeWidth = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  02:05")

        harness.controller.setRemindersPaused(true)
        let pausedWidth = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  Paused")

        harness.controller.setRemindersPaused(false)
        let resumedWidth = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  02:05")

        XCTAssertEqual(pausedWidth, activeWidth, accuracy: 0.001)
        XCTAssertEqual(resumedWidth, activeWidth, accuracy: 0.001)
    }

    func testLongCountdownPauseTransitionKeepsTimerTitleSlotFromShrinkingAcrossTicks() throws {
        let harness = makeHarness()

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 6_000))
        let widthAtHundredMinutes = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  100:00")

        harness.controller.setRemindersPaused(true)
        let pausedWidth = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  Paused")

        harness.controller.setRemindersPaused(false)
        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 5_999))
        let widthAtNinetyNineFiftyNine = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  99:59")

        let expectedStableWidth = max(widthAtHundredMinutes, pausedWidth)
        XCTAssertEqual(widthAtHundredMinutes, expectedStableWidth, accuracy: 0.001)
        XCTAssertEqual(pausedWidth, expectedStableWidth, accuracy: 0.001)
        XCTAssertEqual(widthAtNinetyNineFiftyNine, expectedStableWidth, accuracy: 0.001)
    }

    func testCountdownDigitsRemainInSingleStableTextClassAcrossPerGlyphChanges() throws {
        let harness = makeHarness()

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 10))
        let titleAtTenSeconds = try currentAttributedTitle(for: harness.statusItem)
        let widthAtTenSeconds = ceil(titleAtTenSeconds.size().width)

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 9))
        let titleAtNineSeconds = try currentAttributedTitle(for: harness.statusItem)
        let widthAtNineSeconds = ceil(titleAtNineSeconds.size().width)

        XCTAssertEqual(visibleTimerTitle(from: titleAtTenSeconds), "  00:10")
        XCTAssertEqual(visibleTimerTitle(from: titleAtNineSeconds), "  00:09")
        XCTAssertEqual(titleAtTenSeconds.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(titleAtNineSeconds.attribute(.font, at: 2, effectiveRange: nil) as? NSFont, timerDisplayFont())
        XCTAssertEqual(widthAtNineSeconds, widthAtTenSeconds, accuracy: 0.001)
    }

    func testRestPhasePauseKeepsCountdownVisibleInsteadOfPausedText() throws {
        let harness = makeHarness()

        harness.controller.setStatusDisplayState(.active(phase: .rest, remainingSeconds: 20))
        let widthBeforePause = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  00:20")

        harness.controller.setRemindersPaused(true)
        let widthAfterPause = timerTitleSlotWidth(for: harness.statusItem)

        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  00:20")
        XCTAssertEqual(widthAfterPause, widthBeforePause, accuracy: 0.001)
    }

    func testAwayStateKeepsStableTitleSlotAcrossCountdownTransitionsWithoutExpandingPastPausedWidth() throws {
        let harness = makeHarness()

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 10))
        let countdownWidth = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  00:10")

        harness.controller.setRemindersPaused(true)
        let pausedWidth = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  Paused")

        harness.controller.setRemindersPaused(false)
        harness.controller.setStatusDisplayState(.away)
        let awayWidth = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  Away")

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 9))
        let resumedCountdownWidth = timerTitleSlotWidth(for: harness.statusItem)
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  00:09")

        XCTAssertGreaterThanOrEqual(pausedWidth, countdownWidth)
        XCTAssertEqual(awayWidth, pausedWidth, accuracy: 0.001)
        XCTAssertEqual(resumedCountdownWidth, pausedWidth, accuracy: 0.001)
    }

    func testResetTimerDisplayBaselinesAllowsShorterStableSlotAfterExplicitBoundary() throws {
        let harness = makeHarness()

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 60_000))
        let wideBaselines = harness.controller.timerDisplayBaselines
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  1000:00")

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 59))
        XCTAssertEqual(harness.controller.timerDisplayBaselines.titleSlotWidth, wideBaselines.titleSlotWidth, accuracy: 0.001)
        XCTAssertEqual(harness.controller.timerDisplayBaselines.itemLength, wideBaselines.itemLength, accuracy: 0.001)

        harness.controller.resetTimerDisplayBaselines()

        let resetBaselines = harness.controller.timerDisplayBaselines
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  00:59")
        XCTAssertLessThan(resetBaselines.titleSlotWidth, wideBaselines.titleSlotWidth)
        XCTAssertLessThan(resetBaselines.itemLength, wideBaselines.itemLength)

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 58))

        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  00:58")
        XCTAssertEqual(harness.controller.timerDisplayBaselines.titleSlotWidth, resetBaselines.titleSlotWidth, accuracy: 0.001)
        XCTAssertEqual(harness.controller.timerDisplayBaselines.itemLength, resetBaselines.itemLength, accuracy: 0.001)
    }

    func testDisablingTimerModeClearsTitleSlotWidthAndFutureEnablementRecomputesIt() throws {
        let harness = makeHarness()

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 60_000))
        let wideBaselines = harness.controller.timerDisplayBaselines
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  1000:00")

        harness.controller.setShowsTimerState(false)

        let iconOnlyButton = try XCTUnwrap(harness.statusItem.button)
        XCTAssertEqual(harness.statusItem.length, NSStatusItem.squareLength)
        XCTAssertEqual(harness.controller.timerDisplayBaselines.itemLength, 0, accuracy: 0.001)
        XCTAssertEqual(harness.controller.timerDisplayBaselines.titleSlotWidth, 0, accuracy: 0.001)
        XCTAssertEqual(visibleTimerTitle(from: iconOnlyButton.attributedTitle), "")
        XCTAssertEqual(iconOnlyButton.imagePosition, .imageOnly)

        harness.controller.setStatusDisplayState(.active(phase: .work, remainingSeconds: 59))
        harness.controller.setShowsTimerState(true)

        let recomputedBaselines = harness.controller.timerDisplayBaselines
        XCTAssertEqual(try currentTitle(for: harness.statusItem), "  00:59")
        XCTAssertLessThan(recomputedBaselines.titleSlotWidth, wideBaselines.titleSlotWidth)
        XCTAssertLessThan(recomputedBaselines.itemLength, wideBaselines.itemLength)
        XCTAssertGreaterThan(harness.statusItem.length, NSStatusItem.squareLength)
    }

    private func makeHarness() -> (statusItem: NSStatusItem, controller: StatusItemController) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        addTeardownBlock {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.setShowsTimerState(true)
        controller.install()
        return (statusItem, controller)
    }

    private func currentAttributedTitle(for statusItem: NSStatusItem) throws -> NSAttributedString {
        try XCTUnwrap(statusItem.button?.attributedTitle)
    }

    private func currentTitle(for statusItem: NSStatusItem) throws -> String {
        visibleTimerTitle(from: try currentAttributedTitle(for: statusItem))
    }

    private func timerTitleSlotWidth(for statusItem: NSStatusItem) -> CGFloat {
        guard let title = statusItem.button?.attributedTitle else {
            return 0
        }

        return ceil(title.size().width)
    }

    private func timerDisplayFont() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    private func visibleTimerTitle(from attributedTitle: NSAttributedString) -> String {
        let rawTitle = attributedTitle.string

        if rawTitle.hasSuffix("\t") {
            return String(rawTitle.dropLast())
        }

        return rawTitle
    }
}
