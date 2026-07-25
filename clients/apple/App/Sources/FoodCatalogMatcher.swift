import Foundation
import HealthMonitorCore

enum FoodCatalogMatchKind: Int, Comparable {
    case alias = 1
    case canonicalName = 2

    static func < (lhs: FoodCatalogMatchKind, rhs: FoodCatalogMatchKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct FoodCatalogMatch {
    let item: FoodCatalogItem
    let kind: FoodCatalogMatchKind
}

enum FoodCatalogMatcher {
    static func match(
        recognizedFood: RecognizedFood,
        catalog: [FoodCatalogItem]
    ) -> FoodCatalogMatch? {
        let query = normalized(recognizedFood.name)
        guard !query.isEmpty else { return nil }

        return catalog.compactMap { item -> FoodCatalogMatch? in
            if normalized(item.name) == query {
                return FoodCatalogMatch(item: item, kind: .canonicalName)
            }
            if item.aliases.contains(where: { normalized($0) == query }) {
                return FoodCatalogMatch(item: item, kind: .alias)
            }
            return nil
        }.sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind > rhs.kind }
            if lhs.item.isUserCreated != rhs.item.isUserCreated {
                return lhs.item.isUserCreated
            }
            return lhs.item.catalogIdentifier < rhs.item.catalogIdentifier
        }.first
    }

    static func mealFoodItem(
        recognizedFood: RecognizedFood,
        confirmedWeightGrams: Double? = nil,
        match: FoodCatalogMatch
    ) -> MealFoodItem {
        MealFoodItem(
            catalogIdentifierSnapshot: match.item.catalogIdentifier,
            foodNameSnapshot: match.item.name,
            weightGrams: confirmedWeightGrams
                ?? NSDecimalNumber(decimal: recognizedFood.estimatedWeightGrams).doubleValue,
            cookingMethod: recognizedFood.cookingMethod ?? "",
            nutrientsPer100Grams: match.item.nutrientsPer100Grams,
            sourceDataVersion: match.item.dataVersion
        )
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }
}
