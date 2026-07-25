import Foundation
import Observation

@MainActor
@Observable
final class HealthDashboardModel {
    enum State: Equatable {
        case checkingAuthorization
        case needsAuthorization
        case requesting
        case loading
        case ready
        case unavailable
        case failed(String)
    }

    private let client: any HealthKitClientProtocol

    var state: State
    var summary = TodayActivitySummary.empty
    var overview = HealthOverview.empty
    var lastUpdated: Date?
    var lastSyncResult = HealthActivitySyncResult.empty
    private var isObserving = false

    init(client: any HealthKitClientProtocol = HealthKitClient()) {
        self.client = client
        state = client.isAvailable ? .checkingAuthorization : .unavailable
    }

    func prepare() async {
        guard client.isAvailable else {
            state = .unavailable
            return
        }

        state = .checkingAuthorization
        do {
            switch try await client.authorizationRequestStatus() {
            case .shouldRequest:
                state = .needsAuthorization
            case .unnecessary:
                await refresh()
            case .unknown:
                state = .failed(HealthKitClientError.authorizationStatusUnknown.localizedDescription)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
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
            lastSyncResult = try await client.syncHealthChanges()
            async let activity = client.fetchTodayActivity()
            async let healthOverview = client.fetchHealthOverview()
            summary = try await activity
            overview = try await healthOverview
            lastUpdated = Date()
            state = .ready
            try startObservingIfNeeded()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func startObservingIfNeeded() throws {
        guard !isObserving else { return }
        try client.startObservingHealthChanges { [weak self] in
            await self?.refresh()
        }
        isObserving = true
    }
}
