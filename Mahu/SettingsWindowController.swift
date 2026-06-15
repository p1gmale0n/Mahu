import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsDraftCommitter {
    typealias DraftCommitHandler = () -> SettingsDraftCommitDisposition

    private var handlers: [UUID: DraftCommitHandler] = [:]

    func register(id: UUID, handler: @escaping DraftCommitHandler) {
        handlers[id] = handler
    }

    func unregister(id: UUID) {
        handlers.removeValue(forKey: id)
    }

    func commitAllDrafts() -> Bool {
        handlers.values.reduce(false) { result, handler in
            switch handler() {
            case .noChange:
                return result
            case .committedDraft:
                return true
            }
        }
    }
}

enum SettingsDraftCommitDisposition {
    case noChange
    case committedDraft
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    typealias ContentViewControllerFactory = () -> NSViewController
    typealias WindowFactory = (NSViewController) -> NSWindow
    typealias WindowShouldCloseHandler = () -> Bool

    private let makeContentViewController: ContentViewControllerFactory
    private let windowFactory: WindowFactory
    private let appActivator: () -> Void
    private let fallbackShouldAllowWindowClose: WindowShouldCloseHandler
    private var closeGuardViewModel: SettingsViewModel?
    private var closeDraftCommitter: SettingsDraftCommitter?
    private var saveWarningObservation: AnyCancellable?
    private var acknowledgedSaveWarningRevision = 0

    private(set) var window: NSWindow?

    convenience init(viewModel: SettingsViewModel) {
        let draftCommitter = SettingsDraftCommitter()
        self.init(
            viewModel: viewModel,
            appActivator: {
                NSApp.activate(ignoringOtherApps: true)
            },
            draftCommitter: draftCommitter
        )
    }

    convenience init(
        viewModel: SettingsViewModel,
        appActivator: @escaping () -> Void
    ) {
        self.init(
            viewModel: viewModel,
            appActivator: appActivator,
            draftCommitter: SettingsDraftCommitter()
        )
    }

    convenience init(
        viewModel: SettingsViewModel,
        appActivator: @escaping () -> Void,
        draftCommitter: SettingsDraftCommitter
    ) {
        self.init(
            makeContentViewController: {
                NSHostingController(
                    rootView: SettingsView(
                        viewModel: viewModel,
                        draftCommitter: draftCommitter
                    )
                )
            },
            windowFactory: Self.makeWindow(contentViewController:),
            appActivator: appActivator,
            shouldAllowWindowClose: { true }
        )
        closeGuardViewModel = viewModel
        closeDraftCommitter = draftCommitter
        acknowledgedSaveWarningRevision = viewModel.saveWarningRevision
        observeSaveWarnings(from: viewModel)
    }

    init(
        makeContentViewController: @escaping ContentViewControllerFactory,
        windowFactory: @escaping WindowFactory,
        appActivator: @escaping () -> Void = {},
        shouldAllowWindowClose: @escaping WindowShouldCloseHandler = { true }
    ) {
        self.makeContentViewController = makeContentViewController
        self.windowFactory = windowFactory
        self.appActivator = appActivator
        self.fallbackShouldAllowWindowClose = shouldAllowWindowClose
        super.init()
    }

    func showSettingsWindow() {
        let window = window ?? makeAndStoreWindow()

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
        if let closeGuardViewModel {
            acknowledgedSaveWarningRevision = closeGuardViewModel.saveWarningRevision
        }
        appActivator()
    }

    private func makeAndStoreWindow() -> NSWindow {
        let contentViewController = makeContentViewController()
        let window = windowFactory(contentViewController)
        window.delegate = self
        self.window = window
        return window
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let closeGuardViewModel, let closeDraftCommitter else {
            return fallbackShouldAllowWindowClose()
        }

        let committedDraftOnClose = closeDraftCommitter.commitAllDrafts()
        if committedDraftOnClose && closeGuardViewModel.hasSaveFailure {
            return false
        }

        guard closeGuardViewModel.hasSaveFailure else {
            return true
        }

        return closeGuardViewModel.saveWarningRevision <= acknowledgedSaveWarningRevision
    }

    func shouldAllowApplicationTermination() -> Bool {
        guard let window else {
            return true
        }

        guard window.isVisible || window.isMiniaturized else {
            return true
        }

        let shouldAllowTermination = windowShouldClose(window)
        if shouldAllowTermination == false {
            showSettingsWindow()
        }

        return shouldAllowTermination
    }

    static func makeWindow(contentViewController: NSViewController) -> NSWindow {
        _ = contentViewController.view

        let window = NSWindow(contentViewController: contentViewController)
        window.title = "Mahu Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false

        let fittingSize = contentViewController.view.fittingSize
        let minimumContentSize = NSSize(
            width: SettingsView.minimumContentWidth,
            height: SettingsView.minimumContentHeight
        )
        let preferredContentSize = NSSize(
            width: max(fittingSize.width, SettingsView.preferredContentWidth),
            height: max(fittingSize.height, SettingsView.preferredContentHeight)
        )

        window.setContentSize(preferredContentSize)
        window.contentMinSize = minimumContentSize

        window.center()
        return window
    }

    private func observeSaveWarnings(from viewModel: SettingsViewModel) {
        saveWarningObservation = viewModel.$saveWarningRevision
            .dropFirst()
            .sink { [weak self] revision in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.window?.isVisible == true else {
                        return
                    }

                    self.acknowledgedSaveWarningRevision = max(
                        self.acknowledgedSaveWarningRevision,
                        revision
                    )
                }
            }
    }
}
