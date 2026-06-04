import AppKit
import Dispatch
import Foundation

typealias SleepWakeObservationCancellation = @MainActor () -> Void
typealias SleepWakeObservationRegistrar = @MainActor (
    _ willSleep: @escaping @MainActor () -> Void,
    _ didWake: @escaping @MainActor () -> Void
) -> SleepWakeObservationCancellation

@MainActor
enum LiveSleepWakeObservationRegistrar {
    static func make(
        willSleep: @escaping @MainActor () -> Void,
        didWake: @escaping @MainActor () -> Void
    ) -> SleepWakeObservationCancellation {
        make(
            willSleep: willSleep,
            didWake: didWake,
            workspaceNotificationCenter: NSWorkspace.shared.notificationCenter
        )
    }

    static func make(
        willSleep: @escaping @MainActor () -> Void,
        didWake: @escaping @MainActor () -> Void,
        workspaceNotificationCenter: NotificationCenter
    ) -> SleepWakeObservationCancellation {
        let cancellationState = SleepWakeCancellationState()
        let willSleepObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: nil
        ) { _ in
            deliverSynchronouslyOnMainActor(
                ifNotCancelled: cancellationState,
                willSleep
            )
        }

        let didWakeObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { _ in
            deliverSynchronouslyOnMainActor(
                ifNotCancelled: cancellationState,
                didWake
            )
        }

        return {
            guard cancellationState.cancel() else {
                return
            }

            workspaceNotificationCenter.removeObserver(willSleepObserver)
            workspaceNotificationCenter.removeObserver(didWakeObserver)
        }
    }

    nonisolated private static func deliverSynchronouslyOnMainActor(
        ifNotCancelled cancellationState: SleepWakeCancellationState,
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

private final class SleepWakeCancellationState: @unchecked Sendable {
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
