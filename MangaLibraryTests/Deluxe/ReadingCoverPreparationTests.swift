//
//  ReadingCoverPreparationTests.swift
//  MangaLibraryTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MangaLibrary

@Suite("Bounded Deluxe cover preparation", .tags(.fast))
struct ReadingCoverPreparationTests {
    @Test(arguments: [(800, 400, 384, 192), (400, 800, 192, 384), (128, 64, 128, 64)])
    func `fits the longest side while preserving the source aspect`(
        _ width: Int,
        _ height: Int,
        _ expectedWidth: Int,
        _ expectedHeight: Int
    ) throws {
        let source = try ReadingCoverTestImages.encoded([ReadingCoverTestImages.image(width: width, height: height)])

        let resource = try #require(try ReadingCoverPreparation.prepare(source))
        let image = try ReadingCoverTestImages.decoded(resource.data)

        #expect(image.width == expectedWidth)
        #expect(image.height == expectedHeight)
        #expect(resource.data.count <= 65_536)
        #expect(ReadingCoverTestImages.sourceType(resource.data) == UTType.jpeg.identifier)
    }

    @Test
    func `applies EXIF rotation before writing the bounded JPEG`() throws {
        let source = try ReadingCoverTestImages.encoded(
            [ReadingCoverTestImages.image(width: 800, height: 400)],
            properties: [kCGImagePropertyOrientation: 6]
        )

        let resource = try #require(try ReadingCoverPreparation.prepare(source))
        let image = try ReadingCoverTestImages.decoded(resource.data)
        let properties = try ReadingCoverTestImages.properties(resource.data)

        #expect(image.width == 192)
        #expect(image.height == 384)
        let orientation = properties[kCGImagePropertyOrientation] as? NSNumber
        #expect(orientation == nil || orientation?.intValue == 1)
    }

    @Test
    func `applies mirrored orientation to the actual pixels`() throws {
        let source = try ReadingCoverTestImages.encoded(
            [ReadingCoverTestImages.image(width: 128, height: 64)],
            properties: [kCGImagePropertyOrientation: 2]
        )

        let resource = try #require(try ReadingCoverPreparation.prepare(source))
        let image = try ReadingCoverTestImages.decoded(resource.data)
        let left = try ReadingCoverTestImages.pixel(image, x: 32, y: 32)
        let right = try ReadingCoverTestImages.pixel(image, x: 96, y: 32)

        #expect(left[2] > 200 && left[0] < 60)
        #expect(right[0] > 200 && right[2] < 60)
    }

    @Test
    func `uses the first animation frame as a single JPEG`() throws {
        let first = try ReadingCoverTestImages.image(width: 80, height: 40, pattern: .red)
        let second = try ReadingCoverTestImages.image(width: 80, height: 40, pattern: .blue)
        let source = try ReadingCoverTestImages.encoded([first, second], type: .gif)
        let animated = try #require(CGImageSourceCreateWithData(source as CFData, nil))
        try #require(CGImageSourceGetCount(animated) == 2)

        let resource = try #require(try ReadingCoverPreparation.prepare(source))
        let output = try #require(CGImageSourceCreateWithData(resource.data as CFData, nil))
        let image = try ReadingCoverTestImages.decoded(resource.data)
        let pixel = try ReadingCoverTestImages.pixel(image, x: 40, y: 20)

        #expect(CGImageSourceGetCount(output) == 1)
        #expect(ReadingCoverTestImages.sourceType(resource.data) == UTType.jpeg.identifier)
        #expect(pixel[0] > 200 && pixel[2] < 60)
    }

    @Test
    func `does not copy private source metadata into the JPEG`() throws {
        let source = try ReadingCoverTestImages.encoded(
            [ReadingCoverTestImages.image(width: 128, height: 64)],
            properties: [
                kCGImagePropertyExifDictionary: [
                    kCGImagePropertyExifUserComment: "Synthetic private note"
                ],
                kCGImagePropertyGPSDictionary: [
                    kCGImagePropertyGPSLatitude: 37.0,
                    kCGImagePropertyGPSLatitudeRef: "N"
                ],
                kCGImagePropertyTIFFDictionary: [
                    kCGImagePropertyTIFFMake: "Synthetic private camera"
                ]
            ]
        )
        let original = try ReadingCoverTestImages.properties(source)
        let originalExif = try #require(original[kCGImagePropertyExifDictionary] as? [CFString: Any])
        try #require(originalExif[kCGImagePropertyExifUserComment] as? String == "Synthetic private note")
        try #require(original[kCGImagePropertyGPSDictionary] != nil)

        let resource = try #require(try ReadingCoverPreparation.prepare(source))
        let output = try ReadingCoverTestImages.properties(resource.data)
        let exif = output[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = output[kCGImagePropertyTIFFDictionary] as? [CFString: Any]

        #expect(output[kCGImagePropertyGPSDictionary] == nil)
        #expect(exif?[kCGImagePropertyExifUserComment] == nil)
        #expect(tiff?[kCGImagePropertyTIFFMake] == nil)
    }

    @Test
    func `transcodes a PNG without exposing its original format as a resource`() throws {
        let source = try ReadingCoverTestImages.encoded(
            [ReadingCoverTestImages.image(width: 512, height: 256)],
            type: .png
        )
        try #require(ReadingCoverTestImages.sourceType(source) == UTType.png.identifier)

        let resource = try #require(try ReadingCoverPreparation.prepare(source))
        let image = try ReadingCoverTestImages.decoded(resource.data)

        #expect(ReadingCoverTestImages.sourceType(resource.data) == UTType.jpeg.identifier)
        #expect(image.width == 384)
        #expect(image.height == 192)
        #expect(resource.data.count <= 65_536)
        #expect(ReadingCoverResource(jpegData: source) == nil)
    }

    @Test(arguments: [Data(), Data("This is not an image".utf8), Data([0xFF, 0xD8, 0xFF, 0xD9])])
    func `invalid sources prepare a placeholder instead of a resource`(_ source: Data) throws {
        #expect(try ReadingCoverPreparation.prepare(source) == nil)
        #expect(ReadingCoverResource(jpegData: source) == nil)
    }

    @Test(arguments: [(8_388_608, true), (8_388_609, false)])
    func `bounds complete source bytes before image preparation`(_ byteCount: Int, _ admitted: Bool) throws {
        let jpeg = try ReadingCoverTestImages.encoded([ReadingCoverTestImages.image(width: 64, height: 32)])
        let source = try ReadingCoverTestImages.padded(jpeg, to: byteCount)

        let resource = try ReadingCoverPreparation.prepare(source)

        #expect((resource != nil) == admitted)
    }

    @Test(arguments: [(384, 192, true), (385, 192, false), (192, 385, false)])
    func `resource admission checks both JPEG dimensions`(_ width: Int, _ height: Int, _ admitted: Bool) throws {
        let jpeg = try ReadingCoverTestImages.encoded([ReadingCoverTestImages.image(width: width, height: height)])

        let resource = ReadingCoverResource(jpegData: jpeg)

        #expect((resource != nil) == admitted)
    }

    @Test(arguments: [(65_536, true), (65_537, false)])
    func `resource admission includes all bytes of a complete JPEG`(_ byteCount: Int, _ admitted: Bool) throws {
        let jpeg = try ReadingCoverTestImages.encoded([ReadingCoverTestImages.image(width: 64, height: 32)])
        let bounded = try ReadingCoverTestImages.padded(jpeg, to: byteCount)

        let resource = ReadingCoverResource(jpegData: bounded)

        #expect((resource != nil) == admitted)
    }

    @Test
    func `resource admission rejects a truncated native JPEG`() throws {
        let jpeg = try ReadingCoverTestImages.encoded([ReadingCoverTestImages.image(width: 128, height: 64)])
        let truncated = Data(jpeg.prefix(jpeg.count / 2))

        #expect(ReadingCoverResource(jpegData: truncated) == nil)
        #expect(try ReadingCoverPreparation.prepare(truncated) == nil)
    }

    @Test
    func `content addresses remain stable for identical bytes and change with the image`() throws {
        let red = try ReadingCoverTestImages.encoded([
            ReadingCoverTestImages.image(width: 64, height: 32, pattern: .red)
        ])
        let blue = try ReadingCoverTestImages.encoded([
            ReadingCoverTestImages.image(width: 64, height: 32, pattern: .blue)
        ])

        let first = try #require(ReadingCoverResource(jpegData: red))
        let repeated = try #require(ReadingCoverResource(jpegData: red))
        let changed = try #require(ReadingCoverResource(jpegData: blue))

        #expect(first.identifier == repeated.identifier)
        #expect(first.identifier != changed.identifier)
        #expect(first.identifier.utf8.count == 64)
        #expect(first.identifier.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) })
    }

    @Test(
        arguments: [
            (String(repeating: "a", count: 64), true),
            (String(repeating: "0", count: 64), true),
            ("../cover.jpg", false),
            (String(repeating: "A", count: 64), false),
            (String(repeating: "a", count: 63), false),
            (String(repeating: "a", count: 65), false),
            (String(repeating: "a", count: 63) + "g", false)
        ]
    )
    func `resource identifiers cannot carry paths or alternate spellings`(_ identifier: String, _ accepted: Bool) {
        #expect(ReadingCoverResource.isValidIdentifier(identifier) == accepted)
    }

    @Test
    func `cancellation propagates before preparing a cover`() async throws {
        let source = try ReadingCoverTestImages.encoded([ReadingCoverTestImages.image(width: 800, height: 400)])

        await #expect(throws: CancellationError.self) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.cancelAll()
                group.addTask {
                    _ = try ReadingCoverPreparation.prepare(source)
                }
                try await group.waitForAll()
            }
        }
    }
}

enum ReadingCoverTestImages {
    static func noisySource(seed: UInt32) throws -> Data {
        let dimension = 352
        var state = seed
        var bytes = Data(capacity: dimension * dimension * 4)
        for _ in 0..<(dimension * dimension) {
            state = state &* 1_664_525 &+ 1_013_904_223
            let level = UInt8(truncatingIfNeeded: state >> 24)
            bytes.append(level)
            bytes.append(level)
            bytes.append(level)
            bytes.append(255)
        }
        let provider = try #require(CGDataProvider(data: bytes as CFData))
        let image = try #require(CGImage(
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: dimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        return try encoded([image], type: .png)
    }

    static func jpeg(pattern: Pattern = .split) throws -> Data {
        try encoded([image(width: 64, height: 32, pattern: pattern)])
    }

    enum Pattern {
        case split
        case red
        case blue
    }

    static func image(width: Int, height: Int, pattern: Pattern = .split) throws -> CGImage {
        let context = try rgbaContext(width: width, height: height)
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(width),
            height: CGFloat(height)
        )
        let red = CGColor(
            red: 1,
            green: 0,
            blue: 0,
            alpha: 1
        )
        let blue = CGColor(
            red: 0,
            green: 0,
            blue: 1,
            alpha: 1
        )
        switch pattern {
        case .split:
            context.setFillColor(red)
            context.fill(bounds)
            context.setFillColor(blue)
            context.fill(CGRect(
                x: CGFloat(width) / 2,
                y: 0,
                width: CGFloat(width) / 2,
                height: CGFloat(height)
            ))
        case .red:
            context.setFillColor(red)
            context.fill(bounds)
        case .blue:
            context.setFillColor(blue)
            context.fill(bounds)
        }
        return try #require(context.makeImage())
    }

    static func encoded(_ images: [CGImage], type: UTType = .jpeg, properties: [CFString: Any] = [:]) throws -> Data {
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(
                data as CFMutableData,
                type.identifier as CFString,
                images.count,
                nil
            )
        )
        for image in images {
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        }
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }

    static func decoded(_ data: Data) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(
            CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        )
    }

    static func properties(_ data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    static func sourceType(_ data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceGetType(source) as String?
    }

    static func padded(_ data: Data, to byteCount: Int) throws -> Data {
        try #require(data.count <= byteCount)
        return data + Data(repeating: 0, count: byteCount - data.count)
    }

    static func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        let context = try rgbaContext(width: image.width, height: image.height)
        context.draw(image, in: CGRect(
            x: 0,
            y: 0,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        ))
        let bytes = try #require(context.makeImage()?.dataProvider?.data) as Data
        let offset = y * context.bytesPerRow + x * 4
        return Array(bytes[offset..<(offset + 3)])
    }

    static func rgbaContext(width: Int, height: Int) throws -> CGContext {
        try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            )
        )
    }
}
