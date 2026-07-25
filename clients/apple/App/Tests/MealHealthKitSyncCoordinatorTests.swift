import XCTest
@testable import HealthMonitorAI

@MainActor
final class MealHealthKitSyncCoordinatorTests: XCTestCase {
    func testSyncStoresOnlyUUIDsReturnedByWriter() async throws {
        let references = makeReferences()
        let writer = FakeNutritionWriter(savedReferences: references)
        let meal = makeMeal()

        try await MealHealthKitSyncCoordinator.sync(meal, using: writer)

        XCTAssertEqual(meal.healthKitSampleUUIDs, references.map(\.identifier))
        XCTAssertEqual(meal.healthKitSyncState, .synced)
        let payload = await writer.lastSavedMeal
        XCTAssertEqual(payload?.mealIdentifier, meal.id)
        XCTAssertEqual(payload?.energyKilocalories, 500)
    }

    func testDeleteUsesStoredUUIDsAndClearsReferences() async throws {
        let references = makeReferences()
        let writer = FakeNutritionWriter(savedReferences: [])
        let meal = makeMeal()
        meal.healthKitSampleReferences = references

        try await MealHealthKitSyncCoordinator.deleteHealthSamples(for: meal, using: writer)

        let deletedReferences = await writer.deletedReferences
        XCTAssertEqual(deletedReferences, Set(references))
        XCTAssertTrue(meal.healthKitSampleUUIDs.isEmpty)
    }

    func testMalformedStoredUUIDsAreIgnored() {
        let meal = makeMeal()
        let valid = UUID()
        meal.healthKitSampleUUIDsStorage = "invalid\nHKQuantityTypeIdentifierDietaryEnergyConsumed|\(valid.uuidString)"

        XCTAssertEqual(meal.healthKitSampleUUIDs, [valid])
    }

    private func makeReferences() -> [HealthKitSampleReference] {
        [
            HealthKitSampleReference(
                identifier: UUID(),
                typeIdentifier: "HKQuantityTypeIdentifierDietaryEnergyConsumed"
            ),
            HealthKitSampleReference(
                identifier: UUID(),
                typeIdentifier: "HKQuantityTypeIdentifierDietaryProtein"
            )
        ]
    }

    private func makeMeal() -> MealRecord {
        MealRecord(
            eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
            mealType: .lunch,
            foodName: "测试餐食",
            calories: 500,
            proteinGrams: 25,
            carbohydrateGrams: 60,
            fatGrams: 15,
            fiberGrams: 8,
            sugarGrams: 5,
            sodiumMilligrams: 600,
            waterMilliliters: 250
        )
    }
}

private actor FakeNutritionWriter: HealthKitNutritionWriting {
    let savedReferences: [HealthKitSampleReference]
    private(set) var lastSavedMeal: ConfirmedMealNutrition?
    private(set) var deletedReferences: Set<HealthKitSampleReference> = []

    init(savedReferences: [HealthKitSampleReference]) {
        self.savedReferences = savedReferences
    }

    func saveConfirmedMeal(_ meal: ConfirmedMealNutrition) async throws -> [HealthKitSampleReference] {
        lastSavedMeal = meal
        return savedReferences
    }

    func deleteSamples(with references: Set<HealthKitSampleReference>) async throws {
        deletedReferences = references
    }
}
