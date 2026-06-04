import XCTest
@testable import Mahu

final class BreakTimerTests: XCTestCase {
    func testDefaultConfigStartsInWorkPhase() {
        let timer = BreakTimer()

        XCTAssertEqual(timer.state.phase, .work)
        XCTAssertEqual(timer.state.remainingSeconds, AppConfig.default.workDurationSeconds)
    }

    func testAdvanceUpdatesCountdownAndTransitionsToBreak() {
        let timer = BreakTimer(workDurationSeconds: 10, breakDurationSeconds: 4)

        timer.advance(by: 3)

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: 7))

        timer.advance(by: 7)

        XCTAssertEqual(timer.state, .init(phase: .rest, remainingSeconds: 4))
    }

    func testBreakCompletionStartsNextWorkInterval() {
        let timer = BreakTimer(workDurationSeconds: 10, breakDurationSeconds: 4)

        timer.advance(by: 10)
        timer.advance(by: 4)

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: 10))
    }

    func testSkipBreakStartsNextWorkIntervalImmediately() {
        let timer = BreakTimer(workDurationSeconds: 10, breakDurationSeconds: 4)

        timer.advance(by: 10)
        timer.skipBreak()

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: 10))
    }

    func testSkipBreakDuringWorkDoesNothing() {
        let timer = BreakTimer(workDurationSeconds: 10, breakDurationSeconds: 4)

        timer.skipBreak()

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: 10))
    }

    func testAdvanceHandlesVeryShortDurationsAcrossMultipleTransitions() {
        let timer = BreakTimer(workDurationSeconds: 1, breakDurationSeconds: 0.5)

        timer.advance(by: 1.75)

        XCTAssertEqual(timer.state.phase, .work)
        XCTAssertEqual(timer.state.remainingSeconds, 0.75, accuracy: 0.0001)
    }

    func testAdvanceWithZeroLengthWorkDurationImmediatelyStartsBreakCountdown() {
        let timer = BreakTimer(workDurationSeconds: 0, breakDurationSeconds: 5)

        timer.advance(by: 1)

        XCTAssertEqual(timer.state, .init(phase: .rest, remainingSeconds: 4))
    }

    func testZeroElapsedStillCollapsesZeroLengthWorkIntoBreak() {
        let timer = BreakTimer(workDurationSeconds: 0, breakDurationSeconds: 5)

        timer.advance(by: 0)

        XCTAssertEqual(timer.state, .init(phase: .rest, remainingSeconds: 5))
    }

    func testAdvanceSkipsZeroLengthBreakDurationWithoutReturningRestZero() {
        let timer = BreakTimer(workDurationSeconds: 10, breakDurationSeconds: 0)

        timer.advance(by: 10)

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: 10))
    }

    func testAdvanceWithBothZeroDurationsReturnsStableWorkState() {
        let timer = BreakTimer(workDurationSeconds: 0, breakDurationSeconds: 0)

        timer.advance(by: 1)

        XCTAssertEqual(timer.state, .init(phase: .work, remainingSeconds: 0))
    }
}
