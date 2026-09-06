import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Prepares the first image as a bounded JPEG without copying the source's metadata.
///
/// Invalid, oversized or unencodable sources produce a placeholder. Cancellation propagates,
/// including when it arrives during a native imaging operation. Callers keep this bounded CPU
/// work outside the main actor; preparation does not read files, fetch images or admit resources.
enum ReadingCoverPreparation {
    static let maximumSourceByteCount = 8_388_608
    static let maximumSourcePixelCount = 64_000_000

    static func prepare(_ source: Data) throws -> ReadingCoverResource? {
        try Task.checkCancellation()
        let resource = try preparedResource(source)
        try Task.checkCancellation()
        return resource
    }
}

private extension ReadingCoverPreparation {
    static func preparedResource(_ data: Data) throws -> ReadingCoverResource? {
        guard !data.isEmpty, data.count <= maximumSourceByteCount else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
            let identifier = CGImageSourceGetType(source) as String?,
            let type = UTType(identifier),
            type.conforms(to: .image),
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, sourceOptions) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0,
            height > 0,
            width <= maximumSourcePixelCount / height,
            CGImageSourceGetStatus(source) == .statusComplete,
            CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
        else {
            return nil
        }
        try Task.checkCancellation()
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(ReadingCoverResource.maximumPixelDimension, max(width, height)),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        guard
            (1...ReadingCoverResource.maximumPixelDimension).contains(image.width),
            (1...ReadingCoverResource.maximumPixelDimension).contains(image.height)
        else {
            return nil
        }
        for quality in [0.8, 0.6, 0.4] {
            try Task.checkCancellation()
            if let jpeg = encodedJPEG(image, quality: quality), let resource = ReadingCoverResource(jpegData: jpeg) {
                return resource
            }
        }
        return nil
    }

    static func encodedJPEG(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
