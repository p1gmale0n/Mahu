import AppKit
import Dispatch
import Foundation

typealias SessionActivityObservationCancellation = @MainActor () -> Void
typealias SessionActivityObservationRegistrar = @MainActor (
    _ didResignActive: @escaping @MainActor () -> Void,
    _ didBecomeActive: @escaping @MainActor () -> Void
) -> SessionActivityObservationCancellation

@MainActor
enum LiveSessionActivityObservationRegistrar {
    static func make(
        didResignActive: @escaping @MainActor () -> Void,
        didBecomeActive: @escaping @MainActor () -> Void
    ) -> SessionActivityObservationCancellation {
        make(
            didResignActive: didResignActive,
            didBecomeActive: didBecomeActive,
            workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
        )
    }

    static func make(
        didResignActive: @escaping @MainActor () -> Void,
        didBecomeActive: @escaping @MainActor () -> Void,
        workspaceNotificationCenter: NotificationCenter
    ) -> SessionActivityObservationCancellation {
        let cancellationState = SessionActivityCancellationState()
        let didResignActiveObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            deliverSynchronouslyOnMainActor(
                ifNotCancelled: cancellationState,
                didResignActive
            )
        }

        let didBecomeActiveObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            deliverSynchronouslyOnMainActor(
                ifNotCancelled: cancellationState,
                didBecomeActive
            )
        }

        return {
            guard cancellationState.cancel() else {
                return
            }

            workspaceNotificationCenter.removeObserver(didResignActiveObserver)
            workspaceNotificationCenter.removeObserver(didBecomeActiveObserver)
        }
    }

    nonisolated private static func deliverSynchronouslyOnMainActor(
        ifNotCancelled cancellationState: SessionActivityCancellationState,
        _ handler: @escaping @MainActor () -> Void
    ) {
        guard cancellationState.isCancelled == false else {
            return
        }

        if Thread.isMainThread {
            guard cancellationState.isCancelled == false else {
                return
            }

            MainActor.assumeIsolated {
                handler()
            }
            return
        }

        DispatchQueue.main.sync {
            guard cancellationState.isCancelled == false else {
                return
            }

            MainActor.assumeIsolated {
                handler()
            }
        }
    }
}

private final class SessionActivityCancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard cancelled == false else {
            return false
        }

        cancelled = true
        return true
    }
}
