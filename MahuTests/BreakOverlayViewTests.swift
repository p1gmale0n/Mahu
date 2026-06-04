import AppKit
import SwiftUI
import XCTest
@testable import Mahu

@MainActor
final class BreakOverlayViewTests: XCTestCase {
    func testViewModelSkipInvokesCallback() {
        var didSkip = false
        let viewModel = BreakOverlayViewModel(remainingSeconds: 12) {
            didSkip = true
        }

        viewModel.skip()

        XCTAssertTrue(didSkip)
    }

    func testViewModelFormatsCountdownUsingMinutesAndSeconds() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 65)

        XCTAssertEqual(viewModel.titleText, "Время отвлечься")
        XCTAssertEqual(viewModel.countdownText, "01:05")

        viewModel.updateRemainingSeconds(-5)

        XCTAssertEqual(viewModel.countdownText, "00:00")
    }

    func testBreakOverlayViewContainsRequiredTextAndSkipLabel() {
        let body = BreakOverlayView(viewModel: BreakOverlayViewModel(remainingSeconds: 65)).body
        let textLiterals = extractStringLiterals(
            from: body
        )

        XCTAssertTrue(textLiterals.contains("Время отвлечься"))
        XCTAssertTrue(textLiterals.contains("01:05"))
        XCTAssertTrue(textLiterals.contains("Skip"))
        XCTAssertTrue(textLiterals.contains("background"))
    }

    func testOverlayWindowCanBecomeKeyAndMain() {
        let window = BreakOverlayWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(window.canBecomeKey)
        XCTAssertTrue(window.canBecomeMain)
    }

    private func extractStringLiterals(from value: Any) -> [String] {
        var literals: [String] = []
        collectStringLiterals(from: value, into: &literals)
        return literals
    }

    private func collectStringLiterals(from value: Any, into literals: inout [String]) {
        if let string = value as? String {
            literals.append(string)
        }

        let mirror = Mirror(reflecting: value)
        if "\(mirror.subjectType)".contains("LocalizedStringKey"),
           let key = mirror.children.first(where: { $0.label == "key" })?.value as? String {
            literals.append(key)
        }

        mirror.children.forEach { child in
            collectStringLiterals(from: child.value, into: &literals)
        }
    }
}
