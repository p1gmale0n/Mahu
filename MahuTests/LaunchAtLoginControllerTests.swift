import XCTest
@testable import Mahu

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testSyncRegistersOnceWhenDesiredEnabledAndStatusDisabled() {
        let store = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let manager = FakeLaunchAtLoginManager(status: .disabled)
        manager.statusAfterRegister = .enabled
        let controller = LaunchAtLoginController(settingsStore: store, manager: manager)

        let result = controller.syncDesiredState()

        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertEqual(manager.unregisterCallCount, 0)
        XCTAssertEqual(result, LaunchAtLoginSyncResult(action: .register, status: .enabled, warning: nil))
    }

    func testSyncDoesNotRegisterAgainWhenDesiredEnabledAndAlreadyEnabledOrRequiresApproval() {
        let enabledStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let enabledManager = FakeLaunchAtLoginManager(status: .enabled)
        let enabledController = LaunchAtLoginController(settingsStore: enabledStore, manager: enabledManager)

        let enabledResult = enabledController.syncDesiredState()

        XCTAssertEqual(enabledManager.registerCallCount, 0)
        XCTAssertEqual(enabledResult, LaunchAtLoginSyncResult(action: .none, status: .enabled, warning: nil))

        let approvalStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let approvalManager = FakeLaunchAtLoginManager(status: .requiresApproval)
        let approvalController = LaunchAtLoginController(settingsStore: approvalStore, manager: approvalManager)

        let approvalResult = approvalController.syncDesiredState()

        XCTAssertEqual(approvalManager.registerCallCount, 0)
        XCTAssertEqual(
            approvalResult,
            LaunchAtLoginSyncResult(action: .none, status: .requiresApproval, warning: .requiresApproval)
        )
    }

    func testSyncUnregistersWhenDesiredDisabledAndStatusEnabledOrRequiresApprovalAndNoOpsWhenDisabled() {
        let enabledStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let enabledManager = FakeLaunchAtLoginManager(status: .enabled)
        enabledManager.statusAfterUnregister = .disabled
        let enabledController = LaunchAtLoginController(settingsStore: enabledStore, manager: enabledManager)

        let enabledResult = enabledController.syncDesiredState()

        XCTAssertEqual(enabledManager.unregisterCallCount, 1)
        XCTAssertEqual(enabledResult, LaunchAtLoginSyncResult(action: .unregister, status: .disabled, warning: nil))

        let approvalStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let approvalManager = FakeLaunchAtLoginManager(status: .requiresApproval)
        approvalManager.statusAfterUnregister = .disabled
        let approvalController = LaunchAtLoginController(settingsStore: approvalStore, manager: approvalManager)

        let approvalResult = approvalController.syncDesiredState()

        XCTAssertEqual(approvalManager.unregisterCallCount, 1)
        XCTAssertEqual(approvalResult, LaunchAtLoginSyncResult(action: .unregister, status: .disabled, warning: nil))

        let disabledStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let disabledManager = FakeLaunchAtLoginManager(status: .disabled)
        let disabledController = LaunchAtLoginController(settingsStore: disabledStore, manager: disabledManager)

        let disabledResult = disabledController.syncDesiredState()

        XCTAssertEqual(disabledManager.unregisterCallCount, 0)
        XCTAssertEqual(disabledResult, LaunchAtLoginSyncResult(action: .none, status: .disabled, warning: nil))
    }

    func testSyncReturnsWarningsForUnavailableStatusAndRegistrationOrUnregistrationErrors() {
        let unavailableStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let unavailableManager = FakeLaunchAtLoginManager(status: .unavailable)
        let unavailableController = LaunchAtLoginController(settingsStore: unavailableStore, manager: unavailableManager)

        let unavailableResult = unavailableController.syncDesiredState()

        XCTAssertEqual(unavailableResult, LaunchAtLoginSyncResult(action: .none, status: .unavailable, warning: .unavailable))

        let registerErrorStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let registerErrorManager = FakeLaunchAtLoginManager(status: .disabled)
        registerErrorManager.registerError = TestError.registerFailed
        let registerErrorController = LaunchAtLoginController(settingsStore: registerErrorStore, manager: registerErrorManager)

        let registerErrorResult = registerErrorController.syncDesiredState()

        XCTAssertEqual(
            registerErrorResult,
            LaunchAtLoginSyncResult(action: .register, status: .disabled, warning: .registrationFailed)
        )

        let unregisterErrorStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let unregisterErrorManager = FakeLaunchAtLoginManager(status: .enabled)
        unregisterErrorManager.unregisterError = TestError.unregisterFailed
        let unregisterErrorController = LaunchAtLoginController(settingsStore: unregisterErrorStore, manager: unregisterErrorManager)

        let unregisterErrorResult = unregisterErrorController.syncDesiredState()

        XCTAssertEqual(
            unregisterErrorResult,
            LaunchAtLoginSyncResult(action: .unregister, status: .enabled, warning: .unregistrationFailed)
        )

        let disabledUnavailableStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let disabledUnavailableManager = FakeLaunchAtLoginManager(status: .unavailable)
        let disabledUnavailableController = LaunchAtLoginController(
            settingsStore: disabledUnavailableStore,
            manager: disabledUnavailableManager
        )

        let disabledUnavailableResult = disabledUnavailableController.syncDesiredState()

        XCTAssertEqual(
            disabledUnavailableResult,
            LaunchAtLoginSyncResult(action: .none, status: .unavailable, warning: .unavailable)
        )
    }

    func testSyncReturnsWarningsForPostRegistrationStatusesThatStillNeedAttention() {
        let approvalStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let approvalManager = FakeLaunchAtLoginManager(status: .disabled)
        approvalManager.statusAfterRegister = .requiresApproval
        let approvalController = LaunchAtLoginController(settingsStore: approvalStore, manager: approvalManager)

        let approvalResult = approvalController.syncDesiredState()

        XCTAssertEqual(
            approvalResult,
            LaunchAtLoginSyncResult(action: .register, status: .requiresApproval, warning: .requiresApproval)
        )

        let mismatchStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let mismatchManager = FakeLaunchAtLoginManager(status: .disabled)
        mismatchManager.statusAfterRegister = .disabled
        let mismatchController = LaunchAtLoginController(settingsStore: mismatchStore, manager: mismatchManager)

        let mismatchResult = mismatchController.syncDesiredState()

        XCTAssertEqual(
            mismatchResult,
            LaunchAtLoginSyncResult(action: .register, status: .disabled, warning: .registrationFailed)
        )

        let unavailableStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let unavailableManager = FakeLaunchAtLoginManager(status: .disabled)
        unavailableManager.statusAfterRegister = .unavailable
        let unavailableController = LaunchAtLoginController(settingsStore: unavailableStore, manager: unavailableManager)

        let unavailableResult = unavailableController.syncDesiredState()

        XCTAssertEqual(
            unavailableResult,
            LaunchAtLoginSyncResult(action: .register, status: .unavailable, warning: .unavailable)
        )
    }

    func testSyncReturnsWarningsForPostUnregistrationStatusesThatStillNeedAttention() {
        let unavailableStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let unavailableManager = FakeLaunchAtLoginManager(status: .enabled)
        unavailableManager.statusAfterUnregister = .unavailable
        let unavailableController = LaunchAtLoginController(settingsStore: unavailableStore, manager: unavailableManager)

        let unavailableResult = unavailableController.syncDesiredState()

        XCTAssertEqual(
            unavailableResult,
            LaunchAtLoginSyncResult(action: .unregister, status: .unavailable, warning: .unavailable)
        )

        let mismatchStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let mismatchManager = FakeLaunchAtLoginManager(status: .enabled)
        mismatchManager.statusAfterUnregister = .requiresApproval
        let mismatchController = LaunchAtLoginController(settingsStore: mismatchStore, manager: mismatchManager)

        let mismatchResult = mismatchController.syncDesiredState()

        XCTAssertEqual(
            mismatchResult,
            LaunchAtLoginSyncResult(action: .unregister, status: .requiresApproval, warning: .unregistrationFailed)
        )

        let enabledMismatchStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let enabledMismatchManager = FakeLaunchAtLoginManager(status: .enabled)
        enabledMismatchManager.statusAfterUnregister = .enabled
        let enabledMismatchController = LaunchAtLoginController(
            settingsStore: enabledMismatchStore,
            manager: enabledMismatchManager
        )

        let enabledMismatchResult = enabledMismatchController.syncDesiredState()

        XCTAssertEqual(
            enabledMismatchResult,
            LaunchAtLoginSyncResult(action: .unregister, status: .enabled, warning: .unregistrationFailed)
        )
    }

    func testSyncReportsFinalStatusWhenRegisterOrUnregisterThrowsAfterChangingState() {
        let registerStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        let registerManager = FakeLaunchAtLoginManager(status: .disabled)
        registerManager.statusAfterRegister = .requiresApproval
        registerManager.registerError = TestError.registerFailed
        let registerController = LaunchAtLoginController(settingsStore: registerStore, manager: registerManager)

        let registerResult = registerController.syncDesiredState()

        XCTAssertEqual(
            registerResult,
            LaunchAtLoginSyncResult(action: .register, status: .requiresApproval, warning: .requiresApproval)
        )

        let unregisterStore = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        let unregisterManager = FakeLaunchAtLoginManager(status: .enabled)
        unregisterManager.statusAfterUnregister = .disabled
        unregisterManager.unregisterError = TestError.unregisterFailed
        let unregisterController = LaunchAtLoginController(settingsStore: unregisterStore, manager: unregisterManager)

        let unregisterResult = unregisterController.syncDesiredState()

        XCTAssertEqual(
            unregisterResult,
            LaunchAtLoginSyncResult(action: .unregister, status: .disabled, warning: .unregistrationFailed)
        )
    }

    func testServiceManagementManagerMapsServiceStatusesToAppStatuses() {
        let cases: [(LaunchAtLoginAppServiceStatus, LaunchAtLoginStatus)] = [
            (.enabled, .enabled),
            (.notRegistered, .disabled),
            (.requiresApproval, .requiresApproval),
            (.notFound, .unavailable),
        ]

        for (serviceStatus, expectedStatus) in cases {
            let manager = ServiceManagementLaunchAtLoginManager(
                service: FakeLaunchAtLoginAppService(status: serviceStatus)
            )

            XCTAssertEqual(manager.status, expectedStatus)
        }
    }

    func testServiceManagementManagerForwardsRegisterAndUnregisterCalls() throws {
        let service = FakeLaunchAtLoginAppService(status: .notRegistered)
        let manager = ServiceManagementLaunchAtLoginManager(service: service)

        try manager.register()
        try manager.unregister()

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.unregisterCallCount, 1)
    }

    func testServiceManagementManagerPropagatesRegisterAndUnregisterErrors() {
        let service = FakeLaunchAtLoginAppService(status: .notRegistered)
        service.registerError = TestError.registerFailed
        service.unregisterError = TestError.unregisterFailed
        let manager = ServiceManagementLaunchAtLoginManager(service: service)

        XCTAssertThrowsError(try manager.register())
        XCTAssertThrowsError(try manager.unregister())
    }
}

private enum TestError: Error {
    case registerFailed
    case unregisterFailed
}

private final class FakeLaunchAtLoginManager: LaunchAtLoginManaging {
    var status: LaunchAtLoginStatus
    var statusAfterRegister: LaunchAtLoginStatus?
    var statusAfterUnregister: LaunchAtLoginStatus?
    var registerError: Error?
    var unregisterError: Error?

    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1

        if let statusAfterRegister {
            status = statusAfterRegister
        }

        if let registerError {
            throw registerError
        }
    }

    func unregister() throws {
        unregisterCallCount += 1

        if let statusAfterUnregister {
            status = statusAfterUnregister
        }

        if let unregisterError {
            throw unregisterError
        }
    }
}

private final class FakeLaunchAtLoginAppService: LaunchAtLoginAppServicing {
    var status: LaunchAtLoginAppServiceStatus
    var registerError: Error?
    var unregisterError: Error?

    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: LaunchAtLoginAppServiceStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1

        if let registerError {
            throw registerError
        }
    }

    func unregister() throws {
        unregisterCallCount += 1

        if let unregisterError {
            throw unregisterError
        }
    }
}
