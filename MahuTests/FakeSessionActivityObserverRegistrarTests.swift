import XCTest
@testable import Mahu

@MainActor
final class FakeSessionActivityObserverRegistrarTests: XCTestCase {
    func testDeliversInactiveAndActiveCallbacksDeterministically() {
        let registrar = FakeSessionActivityObserverRegistrar()
        var events: [String] = []

        let cancel = registrar.register(
            didResignActive: { events.append("didResignActive") },
            didBecomeActive: { events.append("didBecomeActive") }
        )
        defer { cancel() }

        registrar.fireDidResignActive()
        registrar.fireDidBecomeActive()

        XCTAssertEqual(events, ["didResignActive", "didBecomeActive"])
        XCTAssertEqual(registrar.didResignActiveCallCount, 1)
        XCTAssertEqual(registrar.didBecomeActiveCallCount, 1)
    }

    func testCancelledObservationStopsLaterDeliveries() {
        let registrar = FakeSessionActivityObserverRegistrar()
        var events: [String] = []

        let cancel = registrar.register(
            didResignActive: { events.append("didResignActive") },
            didBecomeActive: { events.append("didBecomeActive") }
        )
        cancel()
        cancel()

        registrar.fireDidResignActive()
        registrar.fireDidBecomeActive()

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(registrar.cancelCount, 1)
    }

    func testFireAllDeliversAcrossMultipleActiveObservations() {
        let registrar = FakeSessionActivityObserverRegistrar()
        var events: [String] = []

        let cancelOne = registrar.register(
            didResignActive: { events.append("one-didResignActive") },
            didBecomeActive: { events.append("one-didBecomeActive") }
        )
        let cancelTwo = registrar.register(
            didResignActive: { events.append("two-didResignActive") },
            didBecomeActive: { events.append("two-didBecomeActive") }
        )
        defer {
            cancelOne()
            cancelTwo()
        }

        registrar.fireAllDidResignActive()
        registrar.fireAllDidBecomeActive()

        XCTAssertEqual(
            events,
            [
                "one-didResignActive",
                "two-didResignActive",
                "one-didBecomeActive",
                "two-didBecomeActive"
            ]
        )
        XCTAssertEqual(registrar.registrationCount, 2)
    }
}
