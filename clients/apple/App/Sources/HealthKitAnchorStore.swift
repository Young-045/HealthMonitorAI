import Foundation
@preconcurrency import HealthKit

struct StoredHealthQueryState: @unchecked Sendable {
    let anchor: HKQueryAnchor?
    let startDate: Date
}

protocol HealthKitAnchorStoring: Sendable {
    func state(for metric: HealthMetric) throws -> StoredHealthQueryState?
    func save(_ state: StoredHealthQueryState, for metric: HealthMetric) throws
}

enum HealthKitAnchorStoreError: LocalizedError {
    case invalidAnchor

    var errorDescription: String? {
        "已保存的健康同步位置无效，需要重新同步。"
    }
}

final class HealthKitAnchorStore: HealthKitAnchorStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String

    init(defaults: UserDefaults = .standard, keyPrefix: String = "healthkit.sync") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func state(for metric: HealthMetric) throws -> StoredHealthQueryState? {
        let startKey = key(for: metric, suffix: "startDate")
        guard let startDate = defaults.object(forKey: startKey) as? Date else {
            return nil
        }

        let anchorKey = key(for: metric, suffix: "anchor")
        guard let data = defaults.data(forKey: anchorKey) else {
            return StoredHealthQueryState(anchor: nil, startDate: startDate)
        }
        guard let anchor = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: HKQueryAnchor.self,
            from: data
        ) else {
            throw HealthKitAnchorStoreError.invalidAnchor
        }
        return StoredHealthQueryState(anchor: anchor, startDate: startDate)
    }

    func save(_ state: StoredHealthQueryState, for metric: HealthMetric) throws {
        defaults.set(state.startDate, forKey: key(for: metric, suffix: "startDate"))
        if let anchor = state.anchor {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: anchor,
                requiringSecureCoding: true
            )
            defaults.set(data, forKey: key(for: metric, suffix: "anchor"))
        } else {
            defaults.removeObject(forKey: key(for: metric, suffix: "anchor"))
        }
    }

    private func key(for metric: HealthMetric, suffix: String) -> String {
        "\(keyPrefix).\(metric.rawValue).\(suffix)"
    }
}
