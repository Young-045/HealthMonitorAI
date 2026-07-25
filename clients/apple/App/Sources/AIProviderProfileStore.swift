import Foundation
import HealthMonitorCore
import Observation

@MainActor
@Observable
final class AIProviderProfileStore {
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

        profiles = snapshot.profiles
        activeProfileID = snapshot.activeProfileID.flatMap { selectedID in
            snapshot.profiles.contains { $0.id == selectedID } ? selectedID : nil
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
            profiles: profiles,
            activeProfileID: activeProfileID
        ))
        userDefaults.set(data, forKey: storageKey)
    }
}

enum AIProviderProfileStoreError: Error, Equatable {
    case profileNotFound(UUID)
}

private struct Snapshot: Codable {
    let profiles: [AIProviderProfile]
    let activeProfileID: UUID?
}
