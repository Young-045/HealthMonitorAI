import Foundation
import Observation

@MainActor
@Observable
final class HealthDashboardModel {
    enum State: Equatable {
        case needsAuthorization
        case requesting
        case loading
        case ready
        case unavailable
        case failed(String)
    }

    private let client: HealthKitClient

    var state: State
    var summary = TodayActivitySummary.empty
    var lastUpdated: Date?

    init(client: HealthKitClient = HealthKitClient()) {
        self.client = client
        state = client.isAvailable ? .needsAuthorization : .unavailable
    }

    func requestAuthorization() async {
        state = .requesting
        do {
            try await client.requestReadAuthorization()
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        guard client.isAvailable else {
            state = .unavailable
            return
        }

        state = .loading
        do {
            summary = try await client.fetchTodayActivity()
            lastUpdated = Date()
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
