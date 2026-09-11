import Foundation
import ImageIO
import WidgetKit

/// Bounds the decoded artwork before WidgetKit archives it; a SwiftUI frame does not reduce its pixel payload.
enum ReadingWidgetIllustration {
    private static let smallImage = load(maximumPixelSize: 128)
    private static let mediumImage = load(maximumPixelSize: 288)
    private static let largeImage = load(maximumPixelSize: 512)

    static func image(for family: WidgetFamily) -> CGImage? {
        switch family {
        case .systemLarge: largeImage
        case .systemMedium: mediumImage
        default: smallImage
        }
    }

    private static func load(maximumPixelSize: Int) -> CGImage? {
        guard let url = Bundle.main.url(forResource: "WidgetMangaIllustration", withExtension: "png") else {
            return nil
        }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
    }
}
