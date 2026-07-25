import HealthKit
import XCTest
@testable import HealthMonitorAI

final class HealthKitAnchorStoreTests: XCTestCase {
    func testAnchorAndStartDateRoundTrip() throws {
        let suiteName = "HealthKitAnchorStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = HealthKitAnchorStore(defaults: defaults, keyPrefix: "test")
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(
            StoredHealthQueryState(
                anchor: HKQueryAnchor(fromValue: 42),
                startDate: startDate
            ),
            for: .steps
        )
        let restored = try XCTUnwrap(store.state(for: .steps))

        XCTAssertNotNil(restored.anchor)
        XCTAssertEqual(restored.startDate, startDate)
    }

    func testMetricsUseIndependentKeys() throws {
        let suiteName = "HealthKitAnchorStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = HealthKitAnchorStore(defaults: defaults, keyPrefix: "test")

        try store.save(
            StoredHealthQueryState(anchor: nil, startDate: .distantPast),
            for: .activeEnergy
        )

        XCTAssertNil(try store.state(for: .steps))
        XCTAssertEqual(try store.state(for: .activeEnergy)?.startDate, .distantPast)
    }
}
