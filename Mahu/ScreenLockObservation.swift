import Dispatch
import Foundation

typealias ScreenLockObservationCancellation = @MainActor () -> Void
typealias ScreenLockObservationRegistrar = @MainActor (
    _ didLockScreen: @escaping @MainActor () -> Void,
    _ didUnlockScreen: @escaping @MainActor () -> Void
) -> ScreenLockObservationCancellation

@MainActor
enum LiveScreenLockObservationRegistrar {
    private static let screenLockedNotification = Notification.Name("com.apple.screenIsLocked")
    private static let screenUnlockedNotification = Notification.Name("com.apple.screenIsUnlocked")

    static func make(
        didLockScreen: @escaping @MainActor () -> Void,
        didUnlockScreen: @escaping @MainActor () -> Void
    ) -> ScreenLockObservationCancellation {
        make(
            didLockScreen: didLockScreen,
            didUnlockScreen: didUnlockScreen,
            distributedNotificationCenterProvider: { DistributedNotificationCenter.default() }
        )
    }

    static func make(
        didLockScreen: @escaping @MainActor () -> Void,
        didUnlockScreen: @escaping @MainActor () -> Void,
        distributedNotificationCenterProvider: () -> NotificationCenter
    ) -> ScreenLockObservationCancellation {
        make(
            didLockScreen: didLockScreen,
            didUnlockScreen: didUnlockScreen,
            distributedNotificationCenter: distributedNotificationCenterProvider()
        )
    }

    static func make(
        didLockScreen: @escaping @MainActor () -> Void,
        didUnlockScreen: @escaping @MainActor () -> Void,
        distributedNotificationCenter: NotificationCenter
    ) -> ScreenLockObservationCancellation {
        let cancellationState = ObservationCancellationState()
        let didLockObserver = distributedNotificationCenter.addObserver(
            forName: screenLockedNotification,
            object: nil,
            queue: nil
        ) { _ in
            deliverSynchronouslyOnMainActor(
                ifNotCancelled: cancellationState,
                didLockScreen
            )
        }

        let didUnlockObserver = distributedNotificationCenter.addObserver(
            forName: screenUnlockedNotification,
            object: nil,
            queue: nil
        ) { _ in
            deliverSynchronouslyOnMainActor(
                ifNotCancelled: cancellationState,
                didUnlockScreen
            )
        }

        return {
            guard cancellationState.cancel() else {
                return
            }

            distributedNotificationCenter.removeObserver(didLockObserver)
            distributedNotificationCenter.removeObserver(didUnlockObserver)
        }
    }
}
