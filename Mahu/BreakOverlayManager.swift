import AppKit
import Foundation
import OSLog

typealias BreakFocusObservationCancellation = @MainActor () -> Void
typealias BreakFocusObservationRegistrar = @MainActor (@escaping () -> Void) -> BreakFocusObservationCancellation

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
    private let screenObservationRegistrar: BreakScreenObservationRegistrar
    private let appActivator: () -> Void

    private var activeOverlays: [ActiveOverlay] = []
    private(set) var viewModel: BreakOverlayViewModel?
    private var previousFrontmostApplication: PreviousFrontmostApplication?
    private var focusObservationCancellation: BreakFocusObservationCancellation?
    private var screenObservationCancellation: BreakScreenObservationCancellation?
    var onVisibleOverlayWindowsChange: OverlayVisibilityChangeHandler?

    var hasVisibleOverlayWindows: Bool {
        activeOverlays.isEmpty == false
    }

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

    isolated deinit {
        tearDownActiveBreak(restorePreviousApplication: false)
    }

    @discardableResult
    func showBreak(remainingSeconds: TimeInterval, onSkip: @escaping () -> Void = {}) -> Bool {
        let displays = screenProvider()
        guard displays.isEmpty == false else {
            return false
        }

        let previousFrontmostApplication = viewModel == nil ? previousAppCapture() : self.previousFrontmostApplication
        tearDownActiveBreak(restorePreviousApplication: false)

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
        replaceActiveOverlays(with: activeOverlays)
        self.previousFrontmostApplication = previousFrontmostApplication
        replaceFocusObservation(focusObservationRegistrar { [weak self] in
            self?.handleFocusLoss()
        })
        replaceScreenObservation(screenObservationRegistrar { [weak self] in
            self?.handleScreenChange()
        })
        reconcileActiveOverlays(
            for: screenProvider(),
            using: viewModel,
            activateOnChange: false
        )
        appActivator()
        return true
    }

    func updateRemainingSeconds(_ remainingSeconds: TimeInterval) {
        viewModel?.updateRemainingSeconds(remainingSeconds)
    }

    func hideBreak() {
        tearDownActiveBreak(restorePreviousApplication: true)
    }

    private func tearDownActiveBreak(restorePreviousApplication: Bool) {
        let previousFrontmostApplication = restorePreviousApplication ? previousFrontmostApplication : nil

        replaceFocusObservation(nil)
        replaceScreenObservation(nil)
        activeOverlays.forEach { $0.window.close() }
        replaceActiveOverlays(with: [])
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
            closeVisibleOverlaysPreservingBreakState()
            return
        }

        reconcileActiveOverlays(for: displays, using: viewModel, activateOnChange: true)
    }

    private func reconcileActiveOverlays(
        for displays: [DisplayDescriptor],
        using viewModel: BreakOverlayViewModel,
        activateOnChange: Bool
    ) {
        let reconciliation = BreakOverlayReconciler.reconcile(
            activeOverlays: activeOverlays,
            displays: displays,
            viewModel: viewModel,
            windowBuilder: windowBuilder
        )
        replaceActiveOverlays(with: reconciliation.activeOverlays)

        if reconciliation.didChangeWindows && activateOnChange {
            appActivator()
        }
    }

    private func closeVisibleOverlaysPreservingBreakState() {
        guard activeOverlays.isEmpty == false else {
            return
        }

        activeOverlays.forEach { $0.window.close() }
        replaceActiveOverlays(with: [])
    }

    private func replaceActiveOverlays(with newActiveOverlays: [ActiveOverlay]) {
        let wasVisible = activeOverlays.isEmpty == false
        activeOverlays = newActiveOverlays
        let isVisible = newActiveOverlays.isEmpty == false

        guard wasVisible != isVisible else {
            return
        }

        onVisibleOverlayWindowsChange?(isVisible)
    }
}
