import AppKit
import XCTest
@testable import Mahu

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testShowSettingsWindowCreatesOneReusableWindow() {
        let window = SpySettingsWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        var contentViewControllerCreationCount = 0
        var windowFactoryCallCount = 0

        let controller = SettingsWindowController(
            makeContentViewController: {
                contentViewControllerCreationCount += 1
                return NSViewController()
            },
            windowFactory: { contentViewController in
                windowFactoryCallCount += 1
                window.contentViewController = contentViewController
                return window
            }
        )

        controller.showSettingsWindow()
        controller.showSettingsWindow()

        XCTAssertTrue(controller.window === window)
        XCTAssertEqual(contentViewControllerCreationCount, 1)
        XCTAssertEqual(windowFactoryCallCount, 1)
    }

    func testShowSettingsWindowUsesExpectedTitleAndHostingControllerContent() throws {
        let controller = makeController()

        controller.showSettingsWindow()

        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.title, "Mahu Settings")
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertGreaterThan(window.minSize.width, 0)
        XCTAssertGreaterThan(window.minSize.height, 0)
        XCTAssertTrue(String(describing: type(of: try XCTUnwrap(window.contentViewController))).contains("NSHostingController"))
        XCTAssertTrue(String(describing: type(of: try XCTUnwrap(window.contentView))).contains("NSHostingView"))
    }

    func testShowSettingsWindowBringsExistingWindowForwardEachTime() {
        let window = SpySettingsWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        var appActivationCount = 0

        let controller = SettingsWindowController(
            makeContentViewController: { NSViewController() },
            windowFactory: { contentViewController in
                window.contentViewController = contentViewController
                return window
            },
            appActivator: { appActivationCount += 1 }
        )

        controller.showSettingsWindow()
        controller.showSettingsWindow()

        XCTAssertEqual(window.makeKeyAndOrderFrontCallCount, 2)
        XCTAssertEqual(appActivationCount, 2)
    }

    func testShowSettingsWindowRestoresMiniaturizedWindowBeforeBringingItForward() {
        let window = SpySettingsWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.stubIsMiniaturized = true

        let controller = SettingsWindowController(
            makeContentViewController: { NSViewController() },
            windowFactory: { contentViewController in
                window.contentViewController = contentViewController
                return window
            }
        )

        controller.showSettingsWindow()

        XCTAssertEqual(window.deminiaturizeCallCount, 1)
        XCTAssertEqual(window.makeKeyAndOrderFrontCallCount, 1)
    }

    func testClosingWindowCommitsBreakOverlayMessageDraft() throws {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in true },
            dispatchSave: { $0() }
        )
        let controller = SettingsWindowController(
            viewModel: viewModel,
            appActivator: {}
        )

        controller.showSettingsWindow()
        viewModel.updateBreakOverlayMessageDraft(" \n\t ")

        let window = try XCTUnwrap(controller.window)
        let delegate = try XCTUnwrap(window.delegate as? SettingsWindowController)
        delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification, object: window))

        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(
            runtimeSettingsStore.currentSettings.breakOverlayMessageText,
            AppConfig.defaultBreakOverlayMessageText
        )
    }

    private func makeController() -> SettingsWindowController {
        SettingsWindowController(
            viewModel: SettingsViewModel(
                runtimeSettingsStore: RuntimeSettingsStore(initialSettings: .default),
                saveConfig: { _ in true },
                dispatchSave: { $0() }
            ),
            appActivator: {}
        )
    }
}

private final class SpySettingsWindow: NSWindow {
    var stubIsMiniaturized = false
    private(set) var makeKeyAndOrderFrontCallCount = 0
    private(set) var deminiaturizeCallCount = 0

    override var isMiniaturized: Bool {
        stubIsMiniaturized
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        makeKeyAndOrderFrontCallCount += 1
    }

    override func deminiaturize(_ sender: Any?) {
        stubIsMiniaturized = false
        deminiaturizeCallCount += 1
    }
}
