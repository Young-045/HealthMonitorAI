import HealthMonitorCore
import Security
import XCTest

final class KeychainSecretStoreTests: XCTestCase {
    func testSecretLifecycleUsesThisDeviceOnlyAccessibility() throws {
        let service = "KeychainSecretStoreTests.\(UUID().uuidString)"
        let account = "qwen.test.api-key"
        let store = KeychainSecretStore(service: service)
        defer { try? store.delete(account: account) }

        let initialValue: String?
        do {
            initialValue = try store.load(account: account)
        } catch SecretStoreError.keychainStatus(errSecMissingEntitlement) {
            throw XCTSkip("Unsigned simulator builds cannot access Keychain.")
        }
        XCTAssertNil(initialValue)
        try store.save("first-secret", account: account)
        XCTAssertEqual(try store.load(account: account), "first-secret")

        try store.save("replacement-secret", account: account)
        XCTAssertEqual(try store.load(account: account), "replacement-secret")
        XCTAssertEqual(try accessibility(service: service, account: account),
                       kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)

        try store.delete(account: account)
        XCTAssertNil(try store.load(account: account))
    }

    private func accessibility(service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess)
        let attributes = try XCTUnwrap(result as? [String: Any])
        return try XCTUnwrap(attributes[kSecAttrAccessible as String] as? String)
    }
}
