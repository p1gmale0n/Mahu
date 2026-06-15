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
        XCTAssertFalse(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.contentMinSize.width, SettingsView.minimumContentWidth)
        XCTAssertEqual(window.contentMinSize.height, SettingsView.minimumContentHeight)
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.width, SettingsView.preferredContentWidth)
        XCTAssertGreaterThanOrEqual(window.contentLayoutRect.height, SettingsView.preferredContentHeight)
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

    func testWindowShouldCloseCommitsBreakOverlayMessageDraftAndAllowsCloseAfterSuccessfulSave() throws {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in true }
        )
        let controller = SettingsWindowController(
            viewModel: viewModel,
            appActivator: {}
        )

        controller.showSettingsWindow()
        viewModel.updateBreakOverlayMessageDraft(" \n\t ")

        let window = try XCTUnwrap(controller.window)
        let delegate = try XCTUnwrap(window.delegate as? SettingsWindowController)
        let shouldClose = delegate.windowShouldClose(window)

        XCTAssertTrue(shouldClose)
        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(
            runtimeSettingsStore.currentSettings.breakOverlayMessageText,
            AppConfig.defaultBreakOverlayMessageText
        )
    }

    func testWindowShouldCloseKeepsWindowOpenWhenCloseTriggeredDraftSaveFails() throws {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in false }
        )
        let controller = SettingsWindowController(
            viewModel: viewModel,
            appActivator: {}
        )

        controller.showSettingsWindow()
        viewModel.updateBreakOverlayMessageDraft("Next break message")

        let window = try XCTUnwrap(controller.window)
        let delegate = try XCTUnwrap(window.delegate as? SettingsWindowController)
        let shouldClose = delegate.windowShouldClose(window)

        XCTAssertFalse(shouldClose)
        XCTAssertEqual(viewModel.breakOverlayMessageText, "Next break message")
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "Next break message")
        XCTAssertEqual(runtimeSettingsStore.currentSettings.breakOverlayMessageText, "Next break message")
        XCTAssertNotNil(viewModel.saveFailureMessage)
    }

    func testWindowShouldCloseAllowsClosingWhenWarningAlreadyExistsAndNoDraftNeedsCommit() throws {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in false }
        )
        let controller = SettingsWindowController(
            viewModel: viewModel,
            appActivator: {}
        )

        controller.showSettingsWindow()
        viewModel.updateShowMenuTimer(true)
        waitForNextMainQueueTurn()

        let window = try XCTUnwrap(controller.window)
        let delegate = try XCTUnwrap(window.delegate as? SettingsWindowController)
        let shouldClose = delegate.windowShouldClose(window)

        XCTAssertTrue(shouldClose)
        XCTAssertNotNil(viewModel.saveFailureMessage)
        XCTAssertEqual(viewModel.breakOverlayMessageText, AppConfig.defaultBreakOverlayMessageText)
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, AppConfig.defaultBreakOverlayMessageText)
    }

    func testWindowShouldCloseKeepsWindowOpenWhenCloseTriggeredNumericDraftSaveFails() throws {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in false }
        )
        let draftCommitter = SettingsDraftCommitter()
        draftCommitter.register(id: UUID()) {
            _ = viewModel.commitWorkDurationInput(25)
            return .committedDraft
        }
        let controller = SettingsWindowController(
            viewModel: viewModel,
            appActivator: {},
            draftCommitter: draftCommitter
        )

        controller.showSettingsWindow()

        let window = try XCTUnwrap(controller.window)
        let delegate = try XCTUnwrap(window.delegate as? SettingsWindowController)
        let shouldClose = delegate.windowShouldClose(window)

        XCTAssertFalse(shouldClose)
        XCTAssertEqual(viewModel.workDurationMinutes, 25)
        XCTAssertEqual(runtimeSettingsStore.currentSettings.workDurationSeconds, 1_500)
        XCTAssertNotNil(viewModel.saveFailureMessage)
    }

    func testWindowShouldCloseKeepsWindowOpenWhenFocusLossCreatedSaveWarningEarlierInSameTurn() throws {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in false }
        )
        let controller = SettingsWindowController(
            viewModel: viewModel,
            appActivator: {}
        )

        controller.showSettingsWindow()
        viewModel.updateBreakOverlayMessageDraft("Close-created warning")
        viewModel.commitBreakOverlayMessageDraft()

        let window = try XCTUnwrap(controller.window)
        let delegate = try XCTUnwrap(window.delegate as? SettingsWindowController)
        let shouldClose = delegate.windowShouldClose(window)

        XCTAssertFalse(shouldClose)
        XCTAssertNotNil(viewModel.saveFailureMessage)
    }

    func testWindowShouldCloseKeepsWindowOpenWhenDraftCommitFailsWhileWarningAlreadyExists() throws {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in false }
        )
        let controller = SettingsWindowController(
            viewModel: viewModel,
            appActivator: {}
        )

        controller.showSettingsWindow()
        viewModel.updateShowMenuTimer(true)
        waitForNextMainQueueTurn()
        viewModel.updateBreakOverlayMessageDraft("Close-triggered retry")

        let window = try XCTUnwrap(controller.window)
        let delegate = try XCTUnwrap(window.delegate as? SettingsWindowController)
        let shouldClose = delegate.windowShouldClose(window)

        XCTAssertFalse(shouldClose)
        XCTAssertEqual(viewModel.breakOverlayMessageText, "Close-triggered retry")
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "Close-triggered retry")
        XCTAssertNotNil(viewModel.saveFailureMessage)
    }

    func testShouldAllowApplicationTerminationRestoresMiniaturizedWindowWhenDraftSaveFails() throws {
        let runtimeSettingsStore = FakeRuntimeSettingsStore(currentSettings: .default)
        let viewModel = SettingsViewModel(
            runtimeSettingsStore: runtimeSettingsStore,
            saveConfig: { _ in false }
        )
        var appActivationCount = 0
        let controller = SettingsWindowController(
            viewModel: viewModel,
            appActivator: { appActivationCount += 1 }
        )

        controller.showSettingsWindow()
        let window = try XCTUnwrap(controller.window)
        window.miniaturize(nil)
        viewModel.updateBreakOverlayMessageDraft("Quit-triggered miniaturized draft")

        let shouldAllowTermination = controller.shouldAllowApplicationTermination()

        XCTAssertFalse(shouldAllowTermination)
        XCTAssertEqual(viewModel.breakOverlayMessageText, "Quit-triggered miniaturized draft")
        XCTAssertEqual(viewModel.breakOverlayMessageDraftText, "Quit-triggered miniaturized draft")
        XCTAssertNotNil(viewModel.saveFailureMessage)
        XCTAssertFalse(window.isMiniaturized)
        XCTAssertGreaterThanOrEqual(appActivationCount, 2)
    }

    private func makeController() -> SettingsWindowController {
        SettingsWindowController(
            viewModel: SettingsViewModel(
                runtimeSettingsStore: RuntimeSettingsStore(initialSettings: .default),
                saveConfig: { _ in true }
            ),
            appActivator: {}
        )
    }

    private func waitForNextMainQueueTurn() {
        let expectation = expectation(description: "main queue turn")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
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
