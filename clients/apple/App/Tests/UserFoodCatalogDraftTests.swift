import XCTest
@testable import HealthMonitorAI

final class UserFoodCatalogDraftTests: XCTestCase {
    func testDraftCreatesUserCatalogWithNormalizedAliases() throws {
        let identifier = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        let item = try validDraft().makeCatalogItem(identifier: identifier)

        XCTAssertEqual(item.catalogIdentifier, "user.00000000-0000-0000-0000-000000000123")
        XCTAssertEqual(item.name, "熟米饭")
        XCTAssertEqual(item.aliases, ["米饭", "白饭"])
        XCTAssertEqual(item.defaultServingGrams, 150)
        XCTAssertEqual(item.energyKilocaloriesPer100Grams, 116)
        XCTAssertTrue(item.isUserCreated)
        XCTAssertEqual(item.sourceName, "user")
        XCTAssertEqual(item.dataVersion, "user-v1")
    }

    func testDraftRejectsMissingAndInvalidValues() {
        var missingName = validDraft()
        missingName.name = "  "
        XCTAssertThrowsError(try missingName.makeCatalogItem())

        var negativeNutrient = validDraft()
        negativeNutrient.proteinGrams = "-1"
        XCTAssertThrowsError(try negativeNutrient.makeCatalogItem())

        var invalidServing = validDraft()
        invalidServing.defaultServingGrams = "0"
        XCTAssertThrowsError(try invalidServing.makeCatalogItem())
    }

    private func validDraft() -> UserFoodCatalogDraft {
        UserFoodCatalogDraft(
            name: " 熟米饭 ",
            aliases: "米饭，白饭",
            category: .staple,
            defaultServingGrams: "150",
            energyKilocalories: "116",
            proteinGrams: "2.6",
            carbohydrateGrams: "25.9",
            fatGrams: "0.3",
            fiberGrams: "0.3",
            sugarGrams: "0.1",
            sodiumMilligrams: "1"
        )
    }
}
