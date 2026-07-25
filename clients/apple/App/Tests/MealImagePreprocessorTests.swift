import XCTest
import UIKit
@testable import HealthMonitorAI

@MainActor
final class MealImagePreprocessorTests: XCTestCase {
    func testPreprocessorNormalizesAndScalesImage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4_000, height: 2_000))
        let source = renderer.jpegData(withCompressionQuality: 1) { context in
            context.cgContext.setFillColor(UIColor.systemOrange.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4_000, height: 2_000))
        }

        let data = try MealImagePreprocessor.jpegData(from: source)
        let image = try XCTUnwrap(UIImage(data: data))

        XCTAssertEqual(image.size.width, 3_072, accuracy: 1)
        XCTAssertEqual(image.size.height, 1_536, accuracy: 1)
        XCTAssertLessThan(data.count, 7 * 1_024 * 1_024)
    }

    func testPreprocessorRejectsInvalidImageData() {
        XCTAssertThrowsError(try MealImagePreprocessor.jpegData(from: Data([1, 2, 3])))
    }
}
