import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    typealias ContentViewControllerFactory = () -> NSViewController
    typealias WindowFactory = (NSViewController) -> NSWindow

    private let makeContentViewController: ContentViewControllerFactory
    private let windowFactory: WindowFactory
    private let appActivator: () -> Void
    private let onWindowWillClose: () -> Void

    private(set) var window: NSWindow?

    convenience init(viewModel: SettingsViewModel) {
        self.init(
            viewModel: viewModel,
            appActivator: {
                NSApp.activate(ignoringOtherApps: true)
            }
        )
    }

    convenience init(
        viewModel: SettingsViewModel,
        appActivator: @escaping () -> Void
    ) {
        self.init(
            makeContentViewController: {
                NSHostingController(rootView: SettingsView(viewModel: viewModel))
            },
            windowFactory: Self.makeWindow(contentViewController:),
            appActivator: appActivator,
            onWindowWillClose: {
                viewModel.commitBreakOverlayMessageDraft()
            }
        )
    }

    init(
        makeContentViewController: @escaping ContentViewControllerFactory,
        windowFactory: @escaping WindowFactory,
        appActivator: @escaping () -> Void = {},
        onWindowWillClose: @escaping () -> Void = {}
    ) {
        self.makeContentViewController = makeContentViewController
        self.windowFactory = windowFactory
        self.appActivator = appActivator
        self.onWindowWillClose = onWindowWillClose
        super.init()
    }

    func showSettingsWindow() {
        let window = window ?? makeAndStoreWindow()

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
        appActivator()
    }

    private func makeAndStoreWindow() -> NSWindow {
        let contentViewController = makeContentViewController()
        let window = windowFactory(contentViewController)
        window.delegate = self
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        onWindowWillClose()
    }

    static func makeWindow(contentViewController: NSViewController) -> NSWindow {
        _ = contentViewController.view

        let window = NSWindow(contentViewController: contentViewController)
        window.title = "Mahu Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false

        let fittingSize = contentViewController.view.fittingSize
        if fittingSize.width > 0, fittingSize.height > 0 {
            window.setContentSize(fittingSize)
            window.minSize = fittingSize
        }

        window.center()
        return window
    }
}
