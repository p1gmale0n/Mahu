import Foundation
@testable import Mahu

@MainActor
final class FakeOverlayWindowBuilder: BreakOverlayWindowBuilding {
    private(set) var createdDisplays: [DisplayDescriptor] = []
    private(set) var createdViewModels: [BreakOverlayViewModel] = []
    private(set) var windows: [FakeOverlayWindow] = []

    func makeWindow(for display: DisplayDescriptor, viewModel: BreakOverlayViewModel) -> BreakOverlayWindowing {
        createdDisplays.append(display)
        createdViewModels.append(viewModel)

        let window = FakeOverlayWindow()
        windows.append(window)
        return window
    }
}

final class FakeOverlayWindow: BreakOverlayWindowing {
    private(set) var showCallCount = 0
    private(set) var closeCallCount = 0

    func show() {
        showCallCount += 1
    }

    func close() {
        closeCallCount += 1
    }
}

@MainActor
final class FakeBreakFocusObserverRegistrar {
    @MainActor
    private final class Observation {
        private let handler: () -> Void
        private(set) var isCancelled = false

        init(handler: @escaping () -> Void) {
            self.handler = handler
        }

        func fire() {
            guard isCancelled == false else {
                return
            }

            handler()
        }

        func cancel() -> Bool {
            guard isCancelled == false else {
                return false
            }

            isCancelled = true
            return true
        }
    }

    private(set) var registrationCount = 0
    private(set) var handledEventCount = 0
    private(set) var cancelCount = 0
    private(set) var handler: (() -> Void)?
    private var observations: [Observation] = []

    func register(handler: @escaping () -> Void) -> BreakFocusObservationCancellation {
        registrationCount += 1
        let observation = Observation { [weak self] in
            self?.handledEventCount += 1
            handler()
        }
        observations.append(observation)
        self.handler = { [weak observation] in
            observation?.fire()
        }

        return { [weak self, weak observation] in
            guard let self, let observation, observation.cancel() else {
                return
            }

            self.cancelCount += 1
        }
    }

    func fire() {
        handler?()
    }

    func fireAll() {
        observations.forEach { $0.fire() }
    }
}
