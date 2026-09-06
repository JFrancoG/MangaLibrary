import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A complete, bounded JPEG bound to the lowercase SHA-256 of its exact admitted bytes.
///
/// Admission checks byte count, container and dimensions before requesting pixel decoding.
/// The identifier carries no path; readers still verify the file's bytes against this value.
struct ReadingCoverResource: Equatable {
    static let maximumByteCount = 65_536
    static let maximumPixelDimension = 384

    private let storedIdentifier: String
    private let storedData: Data

    var identifier: String { storedIdentifier }
    var data: Data { storedData }
}

extension ReadingCoverResource {
    init?(jpegData: Data) {
        guard !jpegData.isEmpty, jpegData.count <= Self.maximumByteCount else { return nil }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(jpegData as CFData, sourceOptions),
            CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
            CGImageSourceGetCount(source) == 1,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, sourceOptions) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            (1...Self.maximumPixelDimension).contains(width),
            (1...Self.maximumPixelDimension).contains(height),
            CGImageSourceGetStatus(source) == .statusComplete,
            CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
        else {
            return nil
        }
        let decodingOptions = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard
            let image = CGImageSourceCreateImageAtIndex(source, 0, decodingOptions),
            image.width == width,
            image.height == height
        else {
            return nil
        }
        let hexadecimal = Array("0123456789abcdef".utf8)
        let digest = SHA256.hash(data: jpegData).flatMap { byte in
            [hexadecimal[Int(byte >> 4)], hexadecimal[Int(byte & 0x0F)]]
        }
        storedIdentifier = String(decoding: digest, as: UTF8.self)
        storedData = jpegData
    }

    static func isValidIdentifier(_ identifier: String) -> Bool {
        guard identifier.utf8.count == 64 else { return false }
        return identifier.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
