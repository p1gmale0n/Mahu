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
        let view = BreakOverlayView(viewModel: viewModel)
        let foregroundDescription = String(describing: view.foregroundContent)

        XCTAssertTrue(String(describing: type(of: view.body)).contains("GeometryReader"))
        XCTAssertTrue(foregroundDescription.contains("Время отвлечься"))
        XCTAssertTrue(foregroundDescription.contains("01:05"))
        XCTAssertTrue(foregroundDescription.contains("Skip"))
    }

    func testBreakOverlayViewCanBeConstructedWhenBackgroundImageIsUnavailable() throws {
        let emptyBundleURL = try makeEmptyBundle()
        defer {
            try? FileManager.default.removeItem(at: emptyBundleURL)
        }

        let emptyBundle = try XCTUnwrap(Bundle(url: emptyBundleURL))
        let viewModel = BreakOverlayViewModel(remainingSeconds: 9)
        let view = BreakOverlayView(
            viewModel: viewModel,
            backgroundImageLoader: BreakOverlayBackgroundImageLoader(bundle: emptyBundle)
        )
        let foregroundDescription = String(describing: view.foregroundContent)
        let backgroundDescription = String(describing: view.backgroundView)

        XCTAssertNil(view.backgroundImage)
        XCTAssertTrue(String(describing: type(of: view.body)).contains("GeometryReader"))
        XCTAssertTrue(backgroundDescription.contains("falseContent"))
        XCTAssertTrue(foregroundDescription.contains("Время отвлечься"))
        XCTAssertTrue(foregroundDescription.contains("00:09"))
        XCTAssertTrue(foregroundDescription.contains("Skip"))
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
        let view = BreakOverlayView(
            viewModel: viewModel,
            backgroundImageLoader: BreakOverlayBackgroundImageLoader(loadBackgroundImage: {
                NSImage(size: NSSize(width: 1920, height: 1080))
            })
        )
        let foregroundDescription = String(describing: view.foregroundContent)
        let backgroundDescription = String(describing: view.backgroundView)

        XCTAssertNotNil(view.backgroundImage)
        XCTAssertTrue(String(describing: type(of: view.body)).contains("GeometryReader"))
        XCTAssertTrue(backgroundDescription.contains("trueContent"))
        XCTAssertTrue(foregroundDescription.contains("Время отвлечься"))
        XCTAssertTrue(foregroundDescription.contains("00:27"))
        XCTAssertTrue(foregroundDescription.contains("Skip"))
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
        let view = BreakOverlayView(
            viewModel: viewModel,
            backgroundImageLoader: loader
        )
        let foregroundDescription = String(describing: view.foregroundContent)
        let backgroundDescription = String(describing: view.backgroundView)

        XCTAssertNil(loader.loadBackgroundImage())
        XCTAssertNil(view.backgroundImage)
        XCTAssertTrue(String(describing: type(of: view.body)).contains("GeometryReader"))
        XCTAssertTrue(backgroundDescription.contains("falseContent"))
        XCTAssertTrue(foregroundDescription.contains("00:04"))
        XCTAssertTrue(foregroundDescription.contains("Skip"))
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

    func testLiveBreakOverlayWindowAppliesExpectedWindowConfiguration() {
        let display = DisplayDescriptor(frame: CGRect(x: 10, y: 20, width: 640, height: 480))
        let viewModel = BreakOverlayViewModel(remainingSeconds: 9)
        let liveWindow = LiveBreakOverlayWindow(display: display, viewModel: viewModel)
        let window = liveWindow.window

        XCTAssertEqual(window.frame, display.frame)
        XCTAssertEqual(window.level, .screenSaver)
        XCTAssertEqual(window.backgroundColor, .clear)
        XCTAssertFalse(window.isOpaque)
        XCTAssertFalse(window.hasShadow)
        XCTAssertEqual(
            window.collectionBehavior,
            [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        )
        XCTAssertFalse(window.isMovable)
        XCTAssertFalse(window.ignoresMouseEvents)
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertNotNil(window.contentView)
        XCTAssertTrue(String(describing: type(of: window.contentView!)).contains("NSHostingView"))
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
