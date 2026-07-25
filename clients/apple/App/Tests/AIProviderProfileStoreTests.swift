import Foundation
import HealthMonitorCore
import XCTest
@testable import HealthMonitorAI

@MainActor
final class AIProviderProfileStoreTests: XCTestCase {
    func testProfilesAndActiveSelectionPersistLocally() throws {
        let suiteName = "AIProviderProfileStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = AIProviderProfile(
            displayName: "自建模型",
            kind: .openAICompatible,
            baseURL: URL(string: "https://ai.example.com/v1"),
            visionModel: "vision-model",
            textModel: "text-model",
            timeoutSeconds: 45
        )

        let firstStore = AIProviderProfileStore(userDefaults: defaults)
        try firstStore.upsert(profile)
        try firstStore.select(profileID: profile.id)

        let restoredStore = AIProviderProfileStore(userDefaults: defaults)
        XCTAssertEqual(restoredStore.profiles, [profile])
        XCTAssertEqual(restoredStore.activeProfile, profile)
    }

    func testRemovingActiveProfileClearsSelection() throws {
        let suiteName = "AIProviderProfileStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = AIProviderProfile(displayName: "临时", kind: .localRules)
        let store = AIProviderProfileStore(userDefaults: defaults)
        try store.upsert(profile)
        try store.select(profileID: profile.id)

        try store.remove(profileID: profile.id)

        XCTAssertTrue(store.profiles.isEmpty)
        XCTAssertNil(store.activeProfileID)
    }

    func testQwenProfilePersistenceCannotContainAPIKey() throws {
        let profile = AIProviderProfile(
            displayName: "Qwen",
            kind: .qwen,
            baseURL: QwenRegion.chinaBeijing.baseURL,
            textModel: "qwen3.7-plus"
        )

        let data = try JSONEncoder().encode(profile)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(json.localizedCaseInsensitiveContains("apiKey"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("authorization"))
        XCTAssertTrue(AIProviderSecretCoordinator.account(profileID: profile.id).hasPrefix("qwen."))
    }
}
