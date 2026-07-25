import Foundation
import XCTest
@testable import HealthMonitorAI

@MainActor
final class AIHealthSummarySharingStoreTests: XCTestCase {
    func testSharingIsDisabledByDefaultAndPersistsExplicitChoice() throws {
        let suiteName = "AIHealthSummarySharingStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initialStore = AIHealthSummarySharingStore(userDefaults: defaults)
        XCTAssertFalse(initialStore.isEnabled)

        initialStore.setEnabled(true)
        let restoredStore = AIHealthSummarySharingStore(userDefaults: defaults)
        XCTAssertTrue(restoredStore.isEnabled)

        restoredStore.setEnabled(false)
        XCTAssertFalse(AIHealthSummarySharingStore(userDefaults: defaults).isEnabled)
    }
}
