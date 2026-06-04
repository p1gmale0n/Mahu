import AppKit
import Foundation
import OSLog
import SwiftUI

struct DisplayDescriptor: Equatable, Hashable {
    let id: String
    let frame: CGRect

    init(frame: CGRect, id: String? = nil) {
        self.id = id ?? "\(frame.origin.x),\(frame.origin.y),\(frame.size.width),\(frame.size.height)"
        self.frame = frame
    }
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
        NSScreen.screens.map {
            let screenNumber = ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
            return DisplayDescriptor(frame: $0.frame, id: screenNumber)
        }
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
    private struct ActiveOverlay {
        let display: DisplayDescriptor
        let window: BreakOverlayWindowing
    }

    private static let logger = Logger(subsystem: "Mahu", category: "BreakOverlayManager")

    private let screenProvider: () -> [DisplayDescriptor]
    private let windowBuilder: BreakOverlayWindowBuilding
    private let previousAppCapture: () -> PreviousFrontmostApplication?
    private let focusObservationRegistrar: BreakFocusObservationRegistrar
    private let screenObservationRegistrar: BreakScreenObservationRegistrar
    private let appActivator: () -> Void

    private var activeOverlays: [ActiveOverlay] = []
    private(set) var viewModel: BreakOverlayViewModel?
    private var previousFrontmostApplication: PreviousFrontmostApplication?
    private var focusObservationCancellation: BreakFocusObservationCancellation?
    private var screenObservationCancellation: BreakScreenObservationCancellation?

    init(
        screenProvider: @escaping () -> [DisplayDescriptor],
        windowBuilder: BreakOverlayWindowBuilding,
        previousAppCapture: @escaping () -> PreviousFrontmostApplication? = { nil },
        focusObservationRegistrar: @escaping BreakFocusObservationRegistrar = LiveBreakFocusObservationRegistrar.make,
        screenObservationRegistrar: @escaping BreakScreenObservationRegistrar = LiveBreakScreenObservationRegistrar.make,
        appActivator: @escaping () -> Void
    ) {
        self.screenProvider = screenProvider
        self.windowBuilder = windowBuilder
        self.previousAppCapture = previousAppCapture
        self.focusObservationRegistrar = focusObservationRegistrar
        self.screenObservationRegistrar = screenObservationRegistrar
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
            screenObservationRegistrar: LiveBreakScreenObservationRegistrar.make,
            appActivator: { NSApp.activate(ignoringOtherApps: true) }
        )
    }

    @discardableResult
    func showBreak(remainingSeconds: TimeInterval, onSkip: @escaping () -> Void = {}) -> Bool {
        let displays = screenProvider()
        guard displays.isEmpty == false else {
            return false
        }

        let previousFrontmostApplication = activeOverlays.isEmpty ? previousAppCapture() : self.previousFrontmostApplication
        hideBreak(restorePreviousApplication: false)

        let viewModel = BreakOverlayViewModel(remainingSeconds: remainingSeconds) { [weak self] in
            self?.hideBreak()
            onSkip()
        }
        let activeOverlays = displays.map { display in
            let window = windowBuilder.makeWindow(for: display, viewModel: viewModel)
            window.show()
            return ActiveOverlay(display: display, window: window)
        }

        self.viewModel = viewModel
        self.activeOverlays = activeOverlays
        self.previousFrontmostApplication = previousFrontmostApplication
        replaceFocusObservation(focusObservationRegistrar { [weak self] in
            self?.handleFocusLoss()
        })
        replaceScreenObservation(screenObservationRegistrar { [weak self] in
            self?.handleScreenChange()
        })
        appActivator()
        return true
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
        replaceScreenObservation(nil)
        activeOverlays.forEach { $0.window.close() }
        activeOverlays.removeAll()
        viewModel = nil
        self.previousFrontmostApplication = nil
        previousFrontmostApplication?.reactivate()
    }

    private func replaceFocusObservation(_ observationCancellation: BreakFocusObservationCancellation?) {
        focusObservationCancellation?()
        focusObservationCancellation = observationCancellation
    }

    private func replaceScreenObservation(_ observationCancellation: BreakScreenObservationCancellation?) {
        screenObservationCancellation?()
        screenObservationCancellation = observationCancellation
    }

    private func handleFocusLoss() {
        guard !activeOverlays.isEmpty else {
            return
        }

        activeOverlays.forEach { $0.window.show() }
        appActivator()
    }

    private func handleScreenChange() {
        guard let viewModel else {
            return
        }

        let displays = screenProvider()
        guard displays.isEmpty == false else {
            return
        }

        var overlaysByDisplayID = Dictionary(uniqueKeysWithValues: activeOverlays.map { ($0.display.id, $0) })
        var nextActiveOverlays: [ActiveOverlay] = []
        var didChangeWindows = false

        for display in displays {
            guard let existingOverlay = overlaysByDisplayID.removeValue(forKey: display.id) else {
                let window = windowBuilder.makeWindow(for: display, viewModel: viewModel)
                window.show()
                nextActiveOverlays.append(ActiveOverlay(display: display, window: window))
                didChangeWindows = true
                continue
            }

            guard existingOverlay.display != display else {
                nextActiveOverlays.append(existingOverlay)
                continue
            }

            existingOverlay.window.close()
            let replacementWindow = windowBuilder.makeWindow(for: display, viewModel: viewModel)
            replacementWindow.show()
            nextActiveOverlays.append(ActiveOverlay(display: display, window: replacementWindow))
            didChangeWindows = true
        }

        if overlaysByDisplayID.isEmpty == false {
            overlaysByDisplayID.values.forEach { $0.window.close() }
            didChangeWindows = true
        }

        activeOverlays = nextActiveOverlays

        if didChangeWindows {
            appActivator()
        }
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
    let window: NSWindow

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
