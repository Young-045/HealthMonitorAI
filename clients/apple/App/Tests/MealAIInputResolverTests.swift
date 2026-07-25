import XCTest
@testable import HealthMonitorAI

final class MealAIInputResolverTests: XCTestCase {
    func testAIInputTakesPriorityOverFoodName() {
        XCTAssertEqual(
            MealAIInputResolver.effectiveDescription(
                aiDescription: "  一碗牛肉面  ",
                foodName: "面条"
            ),
            "一碗牛肉面"
        )
    }

    func testFoodNameEnablesAIWhenDescriptionIsEmpty() {
        XCTAssertEqual(
            MealAIInputResolver.effectiveDescription(
                aiDescription: " \n ",
                foodName: "  番茄炒蛋 "
            ),
            "番茄炒蛋"
        )
        XCTAssertTrue(MealAIInputResolver.hasInput(
            aiDescription: "",
            foodName: "番茄炒蛋",
            hasImage: false
        ))
    }

    func testImageEnablesAIWithoutText() {
        XCTAssertTrue(MealAIInputResolver.hasInput(
            aiDescription: "",
            foodName: "",
            hasImage: true
        ))
    }

    func testWhitespaceOnlyTextDoesNotEnableAI() {
        XCTAssertFalse(MealAIInputResolver.hasInput(
            aiDescription: " ",
            foodName: "\n",
            hasImage: false
        ))
    }
}
