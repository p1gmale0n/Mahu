import AppKit
import Dispatch
import Foundation

typealias SessionActivityObservationCancellation = @MainActor () -> Void
typealias SessionActivityObservationRegistrar = @MainActor (
    _ didResignActive: @escaping @MainActor () -> Void,
    _ didBecomeActive: @escaping @MainActor () -> Void
) -> SessionActivityObservationCancellation

typealias UserAwayActivityObservationCancellation = @MainActor () -> Void
typealias UserAwayActivityObservationRegistrar = @MainActor (
    _ didBecomeAway: @escaping @MainActor () -> Void,
    _ didBecomeActive: @escaping @MainActor () -> Void
) -> UserAwayActivityObservationCancellation

@MainActor
enum LiveUserAwayActivityObservationRegistrar {
    static func make(
        didBecomeAway: @escaping @MainActor () -> Void,
        didBecomeActive: @escaping @MainActor () -> Void
    ) -> UserAwayActivityObservationCancellation {
        make(
            didBecomeAway: didBecomeAway,
            didBecomeActive: didBecomeActive,
            sessionActivityRegistrar: LiveSessionActivityObservationRegistrar.make,
            screenLockRegistrar: LiveScreenLockObservationRegistrar.make
        )
    }

    static func make(
        didBecomeAway: @escaping @MainActor () -> Void,
        didBecomeActive: @escaping @MainActor () -> Void,
        sessionActivityRegistrar: @escaping SessionActivityObservationRegistrar,
        screenLockRegistrar: @escaping ScreenLockObservationRegistrar,
        screenLockStateProvider: ScreenLockStateProviding = ScreenLockStateProvider(),
        aggregationState: UserAwaySourceAggregationState? = nil
    ) -> UserAwayActivityObservationCancellation {
        let aggregationState = aggregationState ?? UserAwaySourceAggregationState()
        _ = screenLockStateProvider
        let cancelSessionActivity = sessionActivityRegistrar(
            {
                applyUserAwayTransition(
                    aggregationState.updateSessionAway(true),
                    didBecomeAway: didBecomeAway,
                    didBecomeActive: didBecomeActive
                )
            },
            {
                applyUserAwayTransition(
                    aggregationState.updateSessionAway(false),
                    didBecomeAway: didBecomeAway,
                    didBecomeActive: didBecomeActive
                )
            }
        )
        let cancelScreenLock = screenLockRegistrar(
            {
                applyUserAwayTransition(
                    aggregationState.updateScreenLocked(true),
                    didBecomeAway: didBecomeAway,
                    didBecomeActive: didBecomeActive
                )
            },
            {
                applyUserAwayTransition(
                    aggregationState.updateScreenLocked(false),
                    didBecomeAway: didBecomeAway,
                    didBecomeActive: didBecomeActive
                )
            }
        )
        var isCancelled = false

        return {
            guard isCancelled == false else {
                return
            }

            isCancelled = true
            cancelScreenLock()
            cancelSessionActivity()
        }
    }
}

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
        let cancellationState = ObservationCancellationState()
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
}

@MainActor
private func applyUserAwayTransition(
    _ transition: UserAwayTransition,
    didBecomeAway: @escaping @MainActor () -> Void,
    didBecomeActive: @escaping @MainActor () -> Void
) {
    switch transition {
    case .none:
        return
    case .becameAway:
        didBecomeAway()
    case .becameActive:
        didBecomeActive()
    }
}

@MainActor
private enum UserAwayTransition {
    case none
    case becameAway
    case becameActive
}

@MainActor
final class UserAwaySourceAggregationState {
    private var sessionAway = false
    private var screenLocked = false
    private var isUserAway = false

    func seedSessionAwayIfNeeded() {
        sessionAway = true
        isUserAway = true
    }

    func seedScreenLockedIfNeeded() {
        screenLocked = true
        isUserAway = true
    }

    fileprivate func updateSessionAway(_ newValue: Bool) -> UserAwayTransition {
        sessionAway = newValue
        return transitionForCurrentState()
    }

    fileprivate func updateScreenLocked(_ newValue: Bool) -> UserAwayTransition {
        screenLocked = newValue
        return transitionForCurrentState()
    }

    private func transitionForCurrentState() -> UserAwayTransition {
        let shouldBeAway = sessionAway || screenLocked
        guard shouldBeAway != isUserAway else {
            return .none
        }

        isUserAway = shouldBeAway
        return shouldBeAway ? .becameAway : .becameActive
    }
}

final class ObservationCancellationState: @unchecked Sendable {
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

nonisolated func deliverSynchronouslyOnMainActor(
    ifNotCancelled cancellationState: ObservationCancellationState,
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
