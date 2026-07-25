import Foundation
import Observation

@MainActor
@Observable
final class AIHealthSummarySharingStore {
    private(set) var isEnabled: Bool

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "ai.health-summary-sharing.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        isEnabled = userDefaults.bool(forKey: storageKey)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: storageKey)
    }
}
