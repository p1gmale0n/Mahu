import Foundation

@MainActor
protocol LaunchAtLoginSettingsStoring: AnyObject {
    var launchAtLoginEnabled: Bool { get }

    @discardableResult
    func addObserver(_ observer: @escaping (Bool) -> Void) -> () -> Void

    func update(_ launchAtLoginEnabled: Bool)
}

@MainActor
final class LaunchAtLoginSettingsStore: LaunchAtLoginSettingsStoring {
    private(set) var launchAtLoginEnabled: Bool
    private var observers: [UUID: (Bool) -> Void] = [:]

    init(initialLaunchAtLoginEnabled: Bool = false) {
        launchAtLoginEnabled = initialLaunchAtLoginEnabled
    }

    convenience init(initialSettings: AppConfig) {
        self.init(initialLaunchAtLoginEnabled: initialSettings.launchAtLoginEnabled)
    }

    @discardableResult
    func addObserver(_ observer: @escaping (Bool) -> Void) -> () -> Void {
        let observerID = UUID()
        observers[observerID] = observer

        return { [weak self] in
            self?.observers.removeValue(forKey: observerID)
        }
    }

    func update(_ launchAtLoginEnabled: Bool) {
        guard launchAtLoginEnabled != self.launchAtLoginEnabled else {
            return
        }

        self.launchAtLoginEnabled = launchAtLoginEnabled
        let activeObservers = Array(observers.values)
        activeObservers.forEach { $0(launchAtLoginEnabled) }
    }
}
