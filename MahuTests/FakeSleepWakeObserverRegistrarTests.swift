import XCTest
@testable import Mahu

@MainActor
final class FakeSleepWakeObserverRegistrarTests: XCTestCase {
    func testDeliversWillSleepAndDidWakeCallbacksDeterministically() {
        let registrar = FakeSleepWakeObserverRegistrar()
        var events: [String] = []

        let cancel = registrar.register(
            willSleep: { events.append("willSleep") },
            didWake: { events.append("didWake") }
        )
        defer { cancel() }

        registrar.fireWillSleep()
        registrar.fireDidWake()

        XCTAssertEqual(events, ["willSleep", "didWake"])
        XCTAssertEqual(registrar.willSleepCallCount, 1)
        XCTAssertEqual(registrar.didWakeCallCount, 1)
    }

    func testCancelledObservationStopsLaterDeliveries() {
        let registrar = FakeSleepWakeObserverRegistrar()
        var events: [String] = []

        let cancel = registrar.register(
            willSleep: { events.append("willSleep") },
            didWake: { events.append("didWake") }
        )
        cancel()
        cancel()

        registrar.fireWillSleep()
        registrar.fireDidWake()

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(registrar.cancelCount, 1)
    }

    func testFireAllDeliversAcrossMultipleActiveObservations() {
        let registrar = FakeSleepWakeObserverRegistrar()
        var events: [String] = []

        let cancelOne = registrar.register(
            willSleep: { events.append("one-willSleep") },
            didWake: { events.append("one-didWake") }
        )
        let cancelTwo = registrar.register(
            willSleep: { events.append("two-willSleep") },
            didWake: { events.append("two-didWake") }
        )
        defer {
            cancelOne()
            cancelTwo()
        }

        registrar.fireAllWillSleep()
        registrar.fireAllDidWake()

        XCTAssertEqual(
            events,
            ["one-willSleep", "two-willSleep", "one-didWake", "two-didWake"]
        )
        XCTAssertEqual(registrar.registrationCount, 2)
    }
}
