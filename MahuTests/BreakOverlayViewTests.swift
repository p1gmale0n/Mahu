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

    func testViewModelUsesDefaultTitleWhenCustomTextIsOmitted() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 12)

        XCTAssertEqual(viewModel.titleText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testViewModelPreservesCustomUnicodeTitle() {
        let customTitle = "休憩しましょう — отдохни 🌿"
        let viewModel = BreakOverlayViewModel(remainingSeconds: 12, titleText: customTitle)

        XCTAssertEqual(viewModel.titleText, customTitle)
    }

    func testViewModelNormalizesWhitespaceOnlyTitleToDefault() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 12, titleText: "   \n\t  ")

        XCTAssertEqual(viewModel.titleText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testViewModelFormatsCountdownUsingMinutesAndSeconds() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 65)

        XCTAssertEqual(viewModel.titleText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.countdownText, "01:05")

        viewModel.updateRemainingSeconds(-5)

        XCTAssertEqual(viewModel.countdownText, "00:00")
    }

    func testViewModelRoundsFractionalCountdownValuesUpForDisplay() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 0.1)

        XCTAssertEqual(viewModel.countdownText, "00:01")

        viewModel.updateRemainingSeconds(0.999)
        XCTAssertEqual(viewModel.countdownText, "00:01")

        viewModel.updateRemainingSeconds(59.1)
        XCTAssertEqual(viewModel.countdownText, "01:00")

        viewModel.updateRemainingSeconds(60.0)
        XCTAssertEqual(viewModel.countdownText, "01:00")
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

        assertOverlayRendersForegroundContent(
            view,
            expectedTitle: AppConfig.defaultBreakOverlayMessageText,
            expectedCountdown: "01:05"
        )
    }

    func testBreakOverlayViewRendersCustomMessageWithCountdownAndSkip() {
        let customTitle = "休憩しましょう — отдохни 🌿"
        let viewModel = BreakOverlayViewModel(remainingSeconds: 65, titleText: customTitle)
        let view = BreakOverlayView(viewModel: viewModel)

        assertOverlayRendersForegroundContent(
            view,
            expectedTitle: customTitle,
            expectedCountdown: "01:05"
        )
    }

    func testBreakOverlayViewRendersLongCustomMessageWithCountdownAndSkip() {
        let customTitle = "Пора сделать паузу и мягко перевести взгляд вдаль, чтобы дать глазам немного отдохнуть перед следующим рабочим интервалом."
        let viewModel = BreakOverlayViewModel(remainingSeconds: 65, titleText: customTitle)
        let view = BreakOverlayView(viewModel: viewModel)

        assertOverlayRendersForegroundContent(
            view,
            expectedTitle: customTitle,
            expectedCountdown: "01:05"
        )
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

        XCTAssertNil(view.backgroundImage)
        assertOverlayRendersForegroundContent(
            view,
            expectedTitle: AppConfig.defaultBreakOverlayMessageText,
            expectedCountdown: "00:09"
        )
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

        XCTAssertNotNil(view.backgroundImage)
        assertOverlayRendersForegroundContent(
            view,
            expectedTitle: AppConfig.defaultBreakOverlayMessageText,
            expectedCountdown: "00:27"
        )
    }

    func testBreakOverlayViewUsesGeometryBoundedLayoutToKeepForegroundCentered() {
        let viewModel = BreakOverlayViewModel(remainingSeconds: 27)
        let view = BreakOverlayView(
            viewModel: viewModel,
            backgroundImageLoader: BreakOverlayBackgroundImageLoader(loadBackgroundImage: {
                NSImage(size: NSSize(width: 3_456, height: 2_234))
            })
        )

        let bodyType = String(describing: type(of: view.body))

        XCTAssertTrue(
            bodyType.contains("GeometryReader"),
            "BreakOverlayView must size the background and foreground to the hosting window bounds so scaledToFill background images cannot shift foreground centering on built-in displays."
        )
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

        XCTAssertNil(loader.loadBackgroundImage())
        XCTAssertNil(view.backgroundImage)
        assertOverlayRendersForegroundContent(
            view,
            expectedTitle: AppConfig.defaultBreakOverlayMessageText,
            expectedCountdown: "00:04"
        )
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

    private func assertOverlayRendersForegroundContent(
        _ view: BreakOverlayView,
        expectedTitle: String,
        expectedCountdown: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let bodyStringValues = allStringValues(in: view.foregroundContent)

        XCTAssertTrue(bodyStringValues.contains(expectedTitle), file: file, line: line)
        XCTAssertTrue(bodyStringValues.contains(expectedCountdown), file: file, line: line)
        XCTAssertTrue(bodyStringValues.contains("Skip"), file: file, line: line)
    }

    private func allStringValues(in value: Any) -> [String] {
        var values: [String] = []
        collectStringValues(in: value, into: &values)
        return values
    }

    private func collectStringValues(in value: Any, into values: inout [String]) {
        if let stringValue = value as? String {
            values.append(stringValue)
        }

        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            collectStringValues(in: child.value, into: &values)
        }
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
