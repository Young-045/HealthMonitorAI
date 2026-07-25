import Foundation
import HealthMonitorCore

struct AIProviderSecretCoordinator {
    private let secretStore: KeychainSecretStore

    init(secretStore: KeychainSecretStore = KeychainSecretStore()) {
        self.secretStore = secretStore
    }

    func saveAPIKey(_ apiKey: String, profileID: UUID) throws {
        let value = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw AIProviderError.missingAPIKey }
        try secretStore.save(value, account: Self.account(profileID: profileID))
    }

    func loadAPIKey(profileID: UUID) throws -> String? {
        try secretStore.load(account: Self.account(profileID: profileID))
    }

    func hasAPIKey(profileID: UUID) -> Bool {
        (try? loadAPIKey(profileID: profileID)) != nil
    }

    func deleteAPIKey(profileID: UUID) throws {
        try secretStore.delete(account: Self.account(profileID: profileID))
    }

    static func account(profileID: UUID) -> String {
        "qwen.\(profileID.uuidString.lowercased()).api-key"
    }
}
