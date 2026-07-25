import XCTest
@testable import HealthMonitorAI

@MainActor
final class HealthDashboardModelTests: XCTestCase {
    func testPrepareRequestsAuthorizationWhenNeeded() async {
        let model = HealthDashboardModel(client: FakeHealthKitClient(status: .shouldRequest))

        await model.prepare()

        XCTAssertEqual(model.state, .needsAuthorization)
    }

    func testPrepareRefreshesWhenRequestIsUnnecessary() async {
        let summary = TodayActivitySummary(
            steps: 1_234,
            activeEnergyKilocalories: 321,
            restingEnergyKilocalories: 1_200,
            exerciseMinutes: 25,
            unavailableMetrics: []
        )
        let model = HealthDashboardModel(
            client: FakeHealthKitClient(status: .unnecessary, summary: summary)
        )

        await model.prepare()

        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.summary, summary)
        XCTAssertNotNil(model.lastUpdated)
    }

    func testPartialSummaryRemainsReady() async {
        let summary = TodayActivitySummary(
            steps: 1_234,
            activeEnergyKilocalories: nil,
            restingEnergyKilocalories: 1_200,
            exerciseMinutes: 25,
            unavailableMetrics: [.activeEnergy]
        )
        let model = HealthDashboardModel(
            client: FakeHealthKitClient(status: .unnecessary, summary: summary)
        )

        await model.refresh()

        XCTAssertEqual(model.state, .ready)
        XCTAssertTrue(model.summary.isPartiallyAvailable)
        XCTAssertFalse(model.summary.isUnavailable)
    }

    func testUnknownAuthorizationStatusShowsFailure() async {
        let model = HealthDashboardModel(client: FakeHealthKitClient(status: .unknown))

        await model.prepare()

        XCTAssertEqual(
            model.state,
            .failed("暂时无法确认 Apple 健康授权状态，请稍后重试。")
        )
    }

    func testIncrementalSyncFailureIsExposedWithoutDiscardingSummary() async {
        let summary = TodayActivitySummary(
            steps: 500,
            activeEnergyKilocalories: 100,
            restingEnergyKilocalories: 900,
            exerciseMinutes: 10,
            unavailableMetrics: []
        )
        let syncResult = HealthActivitySyncResult(
            addedCount: 2,
            deletedCount: 0,
            failedMetrics: [.activeEnergy]
        )
        let model = HealthDashboardModel(
            client: FakeHealthKitClient(
                status: .unnecessary,
                summary: summary,
                syncResult: syncResult
            )
        )

        await model.refresh()

        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.summary, summary)
        XCTAssertEqual(model.lastSyncResult, syncResult)
    }

    func testUnavailableDeviceDoesNotRequestStatus() async {
        let model = HealthDashboardModel(
            client: FakeHealthKitClient(isAvailable: false, status: .shouldRequest)
        )

        await model.prepare()

        XCTAssertEqual(model.state, .unavailable)
    }

    func testRepeatedObserverRefreshReplacesSummaryWithoutDoubleCounting() async throws {
        let summary = TodayActivitySummary(
            steps: 3_000,
            activeEnergyKilocalories: 250,
            restingEnergyKilocalories: 1_100,
            exerciseMinutes: 20,
            unavailableMetrics: []
        )
        let client = ObserverTestHealthKitClient(summary: summary)
        let model = HealthDashboardModel(client: client)

        await model.refresh()
        try await client.emitChange()

        XCTAssertEqual(model.summary, summary)
        XCTAssertEqual(model.summary.steps, 3_000)
        XCTAssertEqual(client.syncCount, 2)
        XCTAssertEqual(client.observerRegistrationCount, 1)
    }
}

private final class FakeHealthKitClient: HealthKitClientProtocol, @unchecked Sendable {
    let isAvailable: Bool
    private let status: HealthAuthorizationRequestStatus
    private let summary: TodayActivitySummary
    private let syncResult: HealthActivitySyncResult

    init(
        isAvailable: Bool = true,
        status: HealthAuthorizationRequestStatus,
        summary: TodayActivitySummary = .empty,
        syncResult: HealthActivitySyncResult = .empty
    ) {
        self.isAvailable = isAvailable
        self.status = status
        self.summary = summary
        self.syncResult = syncResult
    }

    func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        status
    }

    func requestReadAuthorization() async throws {}

    func syncHealthChanges() async throws -> HealthActivitySyncResult {
        syncResult
    }

    func startObservingHealthChanges(
        handler: @escaping @Sendable () async -> Void
    ) throws {}

    func fetchTodayActivity() async throws -> TodayActivitySummary {
        summary
    }

    func fetchHealthOverview() async throws -> HealthOverview {
        .empty
    }
}

private final class ObserverTestHealthKitClient: HealthKitClientProtocol, @unchecked Sendable {
    let isAvailable = true
    private let summary: TodayActivitySummary
    private let lock = NSLock()
    private var observer: (@Sendable () async -> Void)?
    private var storedSyncCount = 0
    private var storedObserverRegistrationCount = 0

    init(summary: TodayActivitySummary) {
        self.summary = summary
    }

    var syncCount: Int {
        lock.withLock { storedSyncCount }
    }

    var observerRegistrationCount: Int {
        lock.withLock { storedObserverRegistrationCount }
    }

    func authorizationRequestStatus() async throws -> HealthAuthorizationRequestStatus {
        .unnecessary
    }

    func requestReadAuthorization() async throws {}

    func syncHealthChanges() async throws -> HealthActivitySyncResult {
        lock.withLock { storedSyncCount += 1 }
        return .empty
    }

    func startObservingHealthChanges(
        handler: @escaping @Sendable () async -> Void
    ) throws {
        lock.withLock {
            storedObserverRegistrationCount += 1
            observer = handler
        }
    }

    func fetchTodayActivity() async throws -> TodayActivitySummary {
        summary
    }

    func fetchHealthOverview() async throws -> HealthOverview {
        .empty
    }

    func emitChange() async throws {
        let handler = try XCTUnwrap(lock.withLock { observer })
        await handler()
    }
}
