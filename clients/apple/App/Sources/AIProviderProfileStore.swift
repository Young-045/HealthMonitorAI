import Foundation
import HealthMonitorCore
import Observation

@MainActor
@Observable
final class AIProviderProfileStore {
    static let defaultQwenVisionModel = "qwen3.7-plus"

    private(set) var profiles: [AIProviderProfile]
    private(set) var activeProfileID: UUID?

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "ai.provider-profiles.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        guard let data = userDefaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            profiles = []
            activeProfileID = nil
            return
        }

        let restoredProfiles = snapshot.schemaVersion < Snapshot.currentSchemaVersion
            ? snapshot.profiles.map(Self.migratingLegacyProfile)
            : snapshot.profiles
        profiles = restoredProfiles
        activeProfileID = snapshot.activeProfileID.flatMap { selectedID in
            restoredProfiles.contains { $0.id == selectedID } ? selectedID : nil
        }

        if snapshot.schemaVersion < Snapshot.currentSchemaVersion {
            try? persist()
        }
    }

    var activeProfile: AIProviderProfile? {
        guard let activeProfileID else { return nil }
        return profiles.first { $0.id == activeProfileID }
    }

    func upsert(_ profile: AIProviderProfile) throws {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        profiles.sort { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        try persist()
    }

    func select(profileID: UUID?) throws {
        if let profileID, !profiles.contains(where: { $0.id == profileID }) {
            throw AIProviderProfileStoreError.profileNotFound(profileID)
        }
        activeProfileID = profileID
        try persist()
    }

    func remove(profileID: UUID) throws {
        guard profiles.contains(where: { $0.id == profileID }) else {
            throw AIProviderProfileStoreError.profileNotFound(profileID)
        }
        profiles.removeAll { $0.id == profileID }
        if activeProfileID == profileID {
            activeProfileID = nil
        }
        try persist()
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(Snapshot(
            schemaVersion: Snapshot.currentSchemaVersion,
            profiles: profiles,
            activeProfileID: activeProfileID
        ))
        userDefaults.set(data, forKey: storageKey)
    }

    private static func migratingLegacyProfile(_ profile: AIProviderProfile) -> AIProviderProfile {
        guard profile.kind == .qwen,
              profile.visionModel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
            return profile
        }
        var migrated = profile
        migrated.visionModel = defaultQwenVisionModel
        return migrated
    }
}

enum AIProviderProfileStoreError: Error, Equatable {
    case profileNotFound(UUID)
}

private struct Snapshot: Codable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let profiles: [AIProviderProfile]
    let activeProfileID: UUID?

    init(
        schemaVersion: Int,
        profiles: [AIProviderProfile],
        activeProfileID: UUID?
    ) {
        self.schemaVersion = schemaVersion
        self.profiles = profiles
        self.activeProfileID = activeProfileID
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case profiles
        case activeProfileID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        profiles = try container.decode([AIProviderProfile].self, forKey: .profiles)
        activeProfileID = try container.decodeIfPresent(UUID.self, forKey: .activeProfileID)
    }
}
