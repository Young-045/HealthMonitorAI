import Foundation
import UIKit

enum MealImagePreprocessorError: LocalizedError {
    case invalidImage
    case encodedImageTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImage: "无法读取所选图片。"
        case .encodedImageTooLarge: "图片压缩后仍然过大，请选择尺寸更小的图片。"
        }
    }
}

@MainActor
enum MealImagePreprocessor {
    static func jpegData(
        from sourceData: Data,
        maximumDimension: CGFloat = 2_048,
        compressionQuality: CGFloat = 0.82
    ) throws -> Data {
        guard let image = UIImage(data: sourceData),
              image.size.width > 0,
              image.size.height > 0 else {
            throw MealImagePreprocessorError.invalidImage
        }

        let scale = min(
            1,
            maximumDimension / max(image.size.width, image.size.height)
        )
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalized = renderer.image { context in
            context.cgContext.setFillColor(UIColor.systemBackground.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = normalized.jpegData(compressionQuality: compressionQuality),
              data.count < 7 * 1_024 * 1_024 else {
            throw MealImagePreprocessorError.encodedImageTooLarge
        }
        return data
    }
}
