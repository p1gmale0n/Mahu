import AppKit
import Foundation
import OSLog
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

typealias BreakFocusObservationCancellation = @MainActor () -> Void
typealias BreakFocusObservationRegistrar = @MainActor (@escaping () -> Void) -> BreakFocusObservationCancellation

enum LiveScreenProvider {
    static func activeDisplays() -> [DisplayDescriptor] {
        NSScreen.screens.map { DisplayDescriptor(frame: $0.frame) }
    }
}

@MainActor
enum LiveBreakFocusObservationRegistrar {
    static func make(handler: @escaping () -> Void) -> BreakFocusObservationCancellation {
        make(
            handler: handler,
            applicationNotificationCenter: .default,
            workspaceNotificationCenter: NSWorkspace.shared.notificationCenter,
            applicationObject: NSApp,
            currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
            activatedProcessIdentifierResolver: liveActivatedProcessIdentifier(from:)
        )
    }

    static func make(
        handler: @escaping () -> Void,
        applicationNotificationCenter: NotificationCenter,
        workspaceNotificationCenter: NotificationCenter,
        applicationObject: AnyObject?,
        currentProcessIdentifier: Int32,
        activatedProcessIdentifierResolver: @escaping (Notification) -> Int32?
    ) -> BreakFocusObservationCancellation {
        let coalescer = FocusLossNotificationCoalescer(handler: handler)
        let scheduleFocusLoss = {
            _ = Task { @MainActor in
                coalescer.notifyFocusLoss()
            }
        }

        let resignObserver = applicationNotificationCenter.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: applicationObject,
            queue: nil
        ) { _ in
            scheduleFocusLoss()
        }

        let workspaceObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { notification in
            guard let processIdentifier = activatedProcessIdentifierResolver(notification),
                  processIdentifier != currentProcessIdentifier else {
                return
            }

            scheduleFocusLoss()
        }

        var isCancelled = false
        return {
            guard isCancelled == false else {
                return
            }

            isCancelled = true
            applicationNotificationCenter.removeObserver(resignObserver)
            workspaceNotificationCenter.removeObserver(workspaceObserver)
        }
    }

    private static func liveActivatedProcessIdentifier(from notification: Notification) -> Int32? {
        (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
    }
}

@MainActor
final class FocusLossNotificationCoalescer {
    private let handler: () -> Void
    private var isPending = false

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func notifyFocusLoss() {
        guard isPending == false else {
            return
        }

        isPending = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            self.isPending = false
            self.handler()
        }
    }
}

@MainActor
final class BreakOverlayManager {
    private static let logger = Logger(subsystem: "Mahu", category: "BreakOverlayManager")

    private let screenProvider: () -> [DisplayDescriptor]
    private let windowBuilder: BreakOverlayWindowBuilding
    private let previousAppCapture: () -> PreviousFrontmostApplication?
    private let focusObservationRegistrar: BreakFocusObservationRegistrar
    private let appActivator: () -> Void

    private var windows: [BreakOverlayWindowing] = []
    private(set) var viewModel: BreakOverlayViewModel?
    private var previousFrontmostApplication: PreviousFrontmostApplication?
    private var focusObservationCancellation: BreakFocusObservationCancellation?

    init(
        screenProvider: @escaping () -> [DisplayDescriptor],
        windowBuilder: BreakOverlayWindowBuilding,
        previousAppCapture: @escaping () -> PreviousFrontmostApplication? = { nil },
        focusObservationRegistrar: @escaping BreakFocusObservationRegistrar = LiveBreakFocusObservationRegistrar.make,
        appActivator: @escaping () -> Void
    ) {
        self.screenProvider = screenProvider
        self.windowBuilder = windowBuilder
        self.previousAppCapture = previousAppCapture
        self.focusObservationRegistrar = focusObservationRegistrar
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
                    guard frontmostApplication.activate() else {
                        Self.logger.warning("Failed to restore previous frontmost app with pid \(frontmostApplication.processIdentifier, privacy: .public).")
                        return
                    }
                }
            },
            focusObservationRegistrar: LiveBreakFocusObservationRegistrar.make,
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
        replaceFocusObservation(
            windows.isEmpty ? nil : focusObservationRegistrar { [weak self] in
                self?.handleFocusLoss()
            }
        )

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

        replaceFocusObservation(nil)
        windows.forEach { $0.close() }
        windows.removeAll()
        viewModel = nil
        self.previousFrontmostApplication = nil
        previousFrontmostApplication?.reactivate()
    }

    private func replaceFocusObservation(_ observationCancellation: BreakFocusObservationCancellation?) {
        focusObservationCancellation?()
        focusObservationCancellation = observationCancellation
    }

    private func handleFocusLoss() {
        guard !windows.isEmpty else {
            return
        }

        windows.forEach { $0.show() }
        appActivator()
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
