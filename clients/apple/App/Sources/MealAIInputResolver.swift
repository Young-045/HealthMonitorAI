import Foundation

enum MealAIInputResolver {
    static func effectiveDescription(
        aiDescription: String,
        foodName: String
    ) -> String {
        let normalizedAIInput = normalized(aiDescription)
        if !normalizedAIInput.isEmpty {
            return normalizedAIInput
        }
        return normalized(foodName)
    }

    static func hasInput(
        aiDescription: String,
        foodName: String,
        hasImage: Bool
    ) -> Bool {
        hasImage || !effectiveDescription(
            aiDescription: aiDescription,
            foodName: foodName
        ).isEmpty
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
