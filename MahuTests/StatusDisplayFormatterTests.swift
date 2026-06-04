import Foundation
import XCTest
@testable import Mahu

final class StatusDisplayFormatterTests: XCTestCase {
    private let formatter = StatusDisplayFormatter()

    func testFormatsActiveWorkTimerAsMinutesAndSeconds() {
        XCTAssertEqual(
            formatter.string(for: .active(phase: .work, remainingSeconds: 65)),
            "01:05"
        )
    }

    func testFormatsActiveRestTimerAsMinutesAndSeconds() {
        XCTAssertEqual(
            formatter.string(for: .active(phase: .rest, remainingSeconds: 20)),
            "00:20"
        )
    }

    func testFormatsPausedDisplayText() {
        XCTAssertEqual(formatter.string(for: .paused), "Paused")
    }

    func testCountdownFormattingUsesSafeDisplayWholeSecondsBehaviorForEdgeCases() {
        XCTAssertEqual(
            formatter.string(for: .active(phase: .work, remainingSeconds: -5)),
            "00:00"
        )
        XCTAssertEqual(
            formatter.string(for: .active(phase: .work, remainingSeconds: 0.1)),
            "00:01"
        )
        XCTAssertEqual(
            formatter.string(for: .active(phase: .rest, remainingSeconds: 59.1)),
            "01:00"
        )
        XCTAssertEqual(
            formatter.string(for: .active(phase: .rest, remainingSeconds: 172_800)),
            "2880:00"
        )
        XCTAssertEqual(
            formatter.string(for: .active(phase: .work, remainingSeconds: .greatestFiniteMagnitude)),
            "153722867280912930:07"
        )
        XCTAssertEqual(
            formatter.string(for: .active(phase: .work, remainingSeconds: .infinity)),
            "00:00"
        )
    }
}
