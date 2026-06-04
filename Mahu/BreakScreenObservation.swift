import AppKit
import Foundation

typealias BreakScreenObservationCancellation = @MainActor () -> Void
typealias BreakScreenObservationRegistrar = @MainActor (@escaping () -> Void) -> BreakScreenObservationCancellation

@MainActor
enum LiveBreakScreenObservationRegistrar {
    static func make(handler: @escaping () -> Void) -> BreakScreenObservationCancellation {
        make(
            handler: handler,
            notificationCenter: .default,
            applicationObject: NSApp
        )
    }

    static func make(
        handler: @escaping () -> Void,
        notificationCenter: NotificationCenter,
        applicationObject: AnyObject?
    ) -> BreakScreenObservationCancellation {
        let coalescer = ScreenChangeNotificationCoalescer(handler: handler)
        let observer = notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: applicationObject,
            queue: nil
        ) { _ in
            _ = Task { @MainActor in
                coalescer.notifyScreenChange()
            }
        }

        var isCancelled = false
        return {
            guard isCancelled == false else {
                return
            }

            isCancelled = true
            notificationCenter.removeObserver(observer)
        }
    }
}

@MainActor
final class ScreenChangeNotificationCoalescer {
    private let handler: () -> Void
    private var isPending = false

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func notifyScreenChange() {
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
