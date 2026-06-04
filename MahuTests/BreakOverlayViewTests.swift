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

    func testViewModelFormatsCountdownsLongerThanTwentyFourHours() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 172_800)

        XCTAssertEqual(viewModel.countdownText, "2880:00")
    }

    func testSafeDisplayWholeSecondsCapsOverflowValuesWithoutTrapping() {
        XCTAssertEqual(AppConfig.safeDisplayWholeSeconds(.greatestFiniteMagnitude), Int64.max)
        XCTAssertEqual(AppConfig.safeDisplayWholeSeconds(.infinity), 0)
    }

    func testViewModelTreatsNonFiniteCountdownValuesAsZero() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 5)

        viewModel.updateRemainingSeconds(.infinity)

        XCTAssertEqual(viewModel.countdownText, "00:00")
    }

    func testBreakOverlayViewContainsRequiredTextAndSkipLabel() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 65)
        let body = BreakOverlayView(viewModel: viewModel).body

        XCTAssertTrue(String(describing: type(of: body)).contains("GeometryReader"))
        XCTAssertEqual(viewModel.titleText, "Время отвлечься")
        XCTAssertEqual(viewModel.countdownText, "01:05")
    }

    func testBreakOverlayViewCanBeConstructedWhenBackgroundImageIsUnavailable() throws {
        let emptyBundleURL = try makeEmptyBundle()
        defer {
            try? FileManager.default.removeItem(at: emptyBundleURL)
        }

        let emptyBundle = try XCTUnwrap(Bundle(url: emptyBundleURL))
        let viewModel = BreakOverlayViewModel(remainingSeconds: 9)
        let body = BreakOverlayView(
            viewModel: viewModel,
            backgroundImageLoader: BreakOverlayBackgroundImageLoader(bundle: emptyBundle)
        )
        let bodyType = String(describing: type(of: body.body))

        XCTAssertTrue(bodyType.contains("GeometryReader"))
        XCTAssertEqual(viewModel.titleText, "Время отвлечься")
        XCTAssertEqual(viewModel.countdownText, "00:09")
    }

    func testBreakOverlayViewLoadsBackgroundImageOnlyOncePerViewLifetime() {
        var loadCallCount = 0
        let viewModel = BreakOverlayViewModel(remainingSeconds: 9)
        let view = BreakOverlayView(
            viewModel: viewModel,
            backgroundImageLoader: BreakOverlayBackgroundImageLoader(loadBackgroundImage: {
                loadCallCount += 1
                return NSImage(size: NSSize(width: 2, height: 2))
            })
        )

        _ = view.body
        viewModel.updateRemainingSeconds(8)
        _ = view.body

        XCTAssertEqual(loadCallCount, 1)
    }

    func testBreakOverlayViewKeepsForegroundTextWithWideBackgroundImage() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 27)
        let body = BreakOverlayView(
            viewModel: viewModel,
            backgroundImageLoader: BreakOverlayBackgroundImageLoader(loadBackgroundImage: {
                NSImage(size: NSSize(width: 1920, height: 1080))
            })
        )
        let bodyType = String(describing: type(of: body.body))

        XCTAssertTrue(bodyType.contains("GeometryReader"))
        XCTAssertEqual(viewModel.titleText, "Время отвлечься")
        XCTAssertEqual(viewModel.countdownText, "00:27")
    }

    func testBackgroundImageLoaderLoadsHostedAppBundleImage() throws {
        let loader = BreakOverlayBackgroundImageLoader(bundle: .main)

        let image = try XCTUnwrap(loader.loadBackgroundImage())

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testBackgroundImageLoaderReturnsNilWhenResourceMissing() throws {
        let emptyBundleURL = try makeEmptyBundle()
        defer {
            try? FileManager.default.removeItem(at: emptyBundleURL)
        }

        let emptyBundle = try XCTUnwrap(Bundle(url: emptyBundleURL))
        let loader = BreakOverlayBackgroundImageLoader(bundle: emptyBundle)

        XCTAssertNil(loader.loadBackgroundImage())
    }

    func testBackgroundImageLoaderReturnsNilWhenResourceIsUndecodable() throws {
        let invalidBundleURL = try makeBundle(backgroundData: Data("not-a-png".utf8))
        defer {
            try? FileManager.default.removeItem(at: invalidBundleURL)
        }

        let invalidBundle = try XCTUnwrap(Bundle(url: invalidBundleURL))
        let loader = BreakOverlayBackgroundImageLoader(bundle: invalidBundle)
        let viewModel = BreakOverlayViewModel(remainingSeconds: 4)
        let body = BreakOverlayView(
            viewModel: viewModel,
            backgroundImageLoader: loader
        )
        let bodyType = String(describing: type(of: body.body))

        XCTAssertNil(loader.loadBackgroundImage())
        XCTAssertTrue(bodyType.contains("GeometryReader"))
        XCTAssertEqual(viewModel.countdownText, "00:04")
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

    private func makeEmptyBundle() throws -> URL {
        try makeBundle()
    }

    private func makeBundle(backgroundData: Data? = nil) throws -> URL {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        let contentsURL = bundleURL.appendingPathComponent("Contents")
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        let infoPlist: [String: Any] = [
            "CFBundleIdentifier": "com.mahu.tests.EmptyBundle",
            "CFBundleName": "EmptyBundle",
            "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "1",
            "CFBundleShortVersionString": "1.0",
        ]

        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
        try data.write(to: infoPlistURL)
        if let backgroundData {
            try backgroundData.write(to: resourcesURL.appendingPathComponent("background.png"))
        }

        return bundleURL
    }
}
