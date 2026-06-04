import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

protocol LaunchAtLoginManaging {
    var status: LaunchAtLoginStatus { get }

    func register() throws
    func unregister() throws
}

enum LaunchAtLoginSyncAction: Equatable {
    case none
    case register
    case unregister
}

enum LaunchAtLoginSyncWarning: Equatable {
    case requiresApproval
    case unavailable
    case registrationFailed
    case unregistrationFailed
}

@MainActor
protocol LaunchAtLoginSyncing: AnyObject {
    func syncDesiredState() -> LaunchAtLoginSyncResult
}

struct LaunchAtLoginSyncResult: Equatable {
    let action: LaunchAtLoginSyncAction
    let status: LaunchAtLoginStatus
    let warning: LaunchAtLoginSyncWarning?
}

protocol LaunchAtLoginAppServicing {
    var status: LaunchAtLoginAppServiceStatus { get }

    func register() throws
    func unregister() throws
}

enum LaunchAtLoginAppServiceStatus {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

struct MainAppLaunchAtLoginService: LaunchAtLoginAppServicing {
    var status: LaunchAtLoginAppServiceStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .notFound
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

final class ServiceManagementLaunchAtLoginManager: LaunchAtLoginManaging {
    private let service: LaunchAtLoginAppServicing

    init(service: LaunchAtLoginAppServicing = MainAppLaunchAtLoginService()) {
        self.service = service
    }

    var status: LaunchAtLoginStatus {
        switch service.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}

@MainActor
final class LaunchAtLoginController {
    private let settingsStore: LaunchAtLoginSettingsStoring
    private let manager: LaunchAtLoginManaging

    init(
        settingsStore: LaunchAtLoginSettingsStoring,
        manager: LaunchAtLoginManaging
    ) {
        self.settingsStore = settingsStore
        self.manager = manager
    }

    func syncDesiredState() -> LaunchAtLoginSyncResult {
        let desiredEnabled = settingsStore.launchAtLoginEnabled
        let currentStatus = manager.status

        if currentStatus == .unavailable {
            return LaunchAtLoginSyncResult(action: .none, status: .unavailable, warning: .unavailable)
        }

        if desiredEnabled {
            switch currentStatus {
            case .enabled:
                return LaunchAtLoginSyncResult(action: .none, status: .enabled, warning: nil)
            case .requiresApproval:
                return LaunchAtLoginSyncResult(action: .none, status: .requiresApproval, warning: .requiresApproval)
            case .disabled:
                do {
                    try manager.register()
                } catch {
                    return makeErrorResult(
                        action: .register,
                        desiredEnabled: true,
                        fallbackWarning: .registrationFailed
                    )
                }

                return makeResult(action: .register, desiredEnabled: true)
            case .unavailable:
                return LaunchAtLoginSyncResult(action: .none, status: .unavailable, warning: .unavailable)
            }
        }

        switch currentStatus {
        case .disabled:
            return LaunchAtLoginSyncResult(action: .none, status: .disabled, warning: nil)
        case .enabled, .requiresApproval:
            do {
                try manager.unregister()
            } catch {
                return makeErrorResult(
                    action: .unregister,
                    desiredEnabled: false,
                    fallbackWarning: .unregistrationFailed
                )
            }

            return makeResult(action: .unregister, desiredEnabled: false)
        case .unavailable:
            return LaunchAtLoginSyncResult(action: .none, status: .unavailable, warning: .unavailable)
        }
    }

    private func makeResult(
        action: LaunchAtLoginSyncAction,
        desiredEnabled: Bool
    ) -> LaunchAtLoginSyncResult {
        let finalStatus = manager.status
        let warning = warningForFinalStatus(
            finalStatus,
            desiredEnabled: desiredEnabled,
            fallbackWarning: nil
        )

        return LaunchAtLoginSyncResult(action: action, status: finalStatus, warning: warning)
    }

    private func makeErrorResult(
        action: LaunchAtLoginSyncAction,
        desiredEnabled: Bool,
        fallbackWarning: LaunchAtLoginSyncWarning
    ) -> LaunchAtLoginSyncResult {
        let finalStatus = manager.status
        let warning = warningForFinalStatus(
            finalStatus,
            desiredEnabled: desiredEnabled,
            fallbackWarning: fallbackWarning
        )

        return LaunchAtLoginSyncResult(action: action, status: finalStatus, warning: warning)
    }

    private func warningForFinalStatus(
        _ finalStatus: LaunchAtLoginStatus,
        desiredEnabled: Bool,
        fallbackWarning: LaunchAtLoginSyncWarning?
    ) -> LaunchAtLoginSyncWarning? {
        let warning: LaunchAtLoginSyncWarning?

        switch (desiredEnabled, finalStatus) {
        case (_, .unavailable):
            warning = .unavailable
        case (true, .enabled), (false, .disabled):
            warning = nil
        case (true, .requiresApproval):
            warning = .requiresApproval
        case (true, .disabled):
            warning = .registrationFailed
        case (false, .enabled), (false, .requiresApproval):
            warning = .unregistrationFailed
        }

        return warning ?? fallbackWarning
    }
}

extension LaunchAtLoginController: LaunchAtLoginSyncing {
}
