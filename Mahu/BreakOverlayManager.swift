import AppKit
import Foundation
import SwiftUI

struct DisplayDescriptor: Equatable {
    let frame: CGRect
}

struct PreviousFrontmostApplication {
    let reactivate: () -> Void
}

@MainActor
protocol BreakOverlayWindowing: AnyObject {
    func show()
    func close()
}

@MainActor
protocol BreakOverlayWindowBuilding {
    func makeWindow(for display: DisplayDescriptor, viewModel: BreakOverlayViewModel) -> BreakOverlayWindowing
}

enum LiveScreenProvider {
    static func activeDisplays() -> [DisplayDescriptor] {
        NSScreen.screens.map { DisplayDescriptor(frame: $0.frame) }
    }
}

@MainActor
final class BreakOverlayManager {
    private let screenProvider: () -> [DisplayDescriptor]
    private let windowBuilder: BreakOverlayWindowBuilding
    private let previousAppCapture: () -> PreviousFrontmostApplication?
    private let appActivator: () -> Void

    private var windows: [BreakOverlayWindowing] = []
    private(set) var viewModel: BreakOverlayViewModel?
    private var previousFrontmostApplication: PreviousFrontmostApplication?

    init(
        screenProvider: @escaping () -> [DisplayDescriptor],
        windowBuilder: BreakOverlayWindowBuilding,
        previousAppCapture: @escaping () -> PreviousFrontmostApplication? = { nil },
        appActivator: @escaping () -> Void
    ) {
        self.screenProvider = screenProvider
        self.windowBuilder = windowBuilder
        self.previousAppCapture = previousAppCapture
        self.appActivator = appActivator
    }

    convenience init() {
        self.init(
            screenProvider: LiveScreenProvider.activeDisplays,
            windowBuilder: LiveBreakOverlayWindowBuilder(),
            previousAppCapture: {
                guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
                      frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                    return nil
                }

                return PreviousFrontmostApplication {
                    _ = frontmostApplication.activate()
                }
            },
            appActivator: { NSApp.activate(ignoringOtherApps: true) }
        )
    }

    func showBreak(remainingSeconds: TimeInterval, onSkip: @escaping () -> Void = {}) {
        let previousFrontmostApplication = windows.isEmpty ? previousAppCapture() : self.previousFrontmostApplication
        hideBreak(restorePreviousApplication: false)

        let viewModel = BreakOverlayViewModel(remainingSeconds: remainingSeconds) { [weak self] in
            self?.hideBreak()
            onSkip()
        }
        let windows = screenProvider().map { display in
            let window = windowBuilder.makeWindow(for: display, viewModel: viewModel)
            window.show()
            return window
        }

        self.viewModel = viewModel
        self.windows = windows
        self.previousFrontmostApplication = windows.isEmpty ? nil : previousFrontmostApplication

        if !windows.isEmpty {
            appActivator()
        }
    }

    func updateRemainingSeconds(_ remainingSeconds: TimeInterval) {
        viewModel?.updateRemainingSeconds(remainingSeconds)
    }

    func hideBreak() {
        hideBreak(restorePreviousApplication: true)
    }

    private func hideBreak(restorePreviousApplication: Bool) {
        let previousFrontmostApplication = restorePreviousApplication ? previousFrontmostApplication : nil

        windows.forEach { $0.close() }
        windows.removeAll()
        viewModel = nil
        self.previousFrontmostApplication = nil
        previousFrontmostApplication?.reactivate()
    }
}

@MainActor
final class LiveBreakOverlayWindowBuilder: BreakOverlayWindowBuilding {
    func makeWindow(for display: DisplayDescriptor, viewModel: BreakOverlayViewModel) -> BreakOverlayWindowing {
        LiveBreakOverlayWindow(display: display, viewModel: viewModel)
    }
}

final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

@MainActor
final class LiveBreakOverlayWindow: BreakOverlayWindowing {
    private let window: NSWindow

    init(display: DisplayDescriptor, viewModel: BreakOverlayViewModel) {
        let window = BreakOverlayWindow(
            contentRect: display.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovable = false
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: BreakOverlayView(viewModel: viewModel))

        self.window = window
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}
