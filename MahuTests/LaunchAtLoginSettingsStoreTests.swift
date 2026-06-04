import XCTest
@testable import Mahu

@MainActor
final class LaunchAtLoginSettingsStoreTests: XCTestCase {
    func testInitializesFromConfigBackedDesiredState() {
        let config = AppConfig(
            workDurationSeconds: 1_200,
            breakDurationSeconds: 20,
            launchAtLoginEnabled: true
        )

        let store = LaunchAtLoginSettingsStore(initialSettings: config)

        XCTAssertTrue(store.launchAtLoginEnabled)
    }

    func testPublishesAcceptedUpdatesToObservers() {
        let store = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        var observerEvents: [Bool] = []

        _ = store.addObserver { observerEvents.append($0) }

        store.update(true)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(observerEvents, [true])
    }

    func testRepeatedIdenticalUpdatesAreNoOps() {
        let store = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: true)
        var observerEvents: [Bool] = []

        _ = store.addObserver { observerEvents.append($0) }

        store.update(true)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertTrue(observerEvents.isEmpty)
    }

    func testObserverCancellationStopsFutureCallbacks() {
        let store = LaunchAtLoginSettingsStore(initialLaunchAtLoginEnabled: false)
        var firstObserverEvents: [Bool] = []
        var secondObserverEvents: [Bool] = []

        let cancelFirstObserver = store.addObserver { firstObserverEvents.append($0) }
        _ = store.addObserver { secondObserverEvents.append($0) }

        store.update(true)
        cancelFirstObserver()
        store.update(false)

        XCTAssertEqual(firstObserverEvents, [true])
        XCTAssertEqual(secondObserverEvents, [true, false])
    }
}
