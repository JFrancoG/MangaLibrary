//
//  LibraryColorTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
import UIKit
@testable import MangaLibrary

@MainActor
@Suite("Library Red", .tags(.fast))
struct LibraryColorTests {
    @Test("The source catalog matches the canonical contract")
    func sourceCatalogMatchesContract() throws {
        let contract = try LibraryColorContract.load()
        let catalogURL = LibraryColorContract.repositoryURL.appending(path: "MangaLibrary/Resources/Assets.xcassets")
        let entries = try FileManager.default.contentsOfDirectory(at: catalogURL, includingPropertiesForKeys: nil)
        let colorSetNames = Set(
            entries
                .filter { $0.pathExtension == "colorset" }
                .map { $0.deletingPathExtension().lastPathComponent }
        )
        let expectedNames = Set(contract.roles.keys)

        #expect(colorSetNames == expectedNames)

        for name in expectedNames.sorted() {
            let assetURL = catalogURL.appending(path: "\(name).colorset/Contents.json")
            let asset = try JSONDecoder().decode(ColorAsset.self, from: Data(contentsOf: assetURL))

            #expect(asset.colors.count == LibraryAppearance.allCases.count)

            for appearance in LibraryAppearance.allCases {
                let entry = try #require(
                    asset.colors.first { $0.traits == appearance.assetTraits }
                )
                let expected = try contract.components(for: name, appearance: appearance)
                let actual = try entry.color.sRGBComponents()

                #expect(entry.idiom == "universal")
                #expect(entry.color.colorSpace == "srgb")
                #expect(actual == expected)
            }
        }
    }

    @Test("The compiled colors resolve exactly in every appearance")
    func compiledColorsResolveExactly() throws {
        let contract = try LibraryColorContract.load()

        for appearance in LibraryAppearance.allCases {
            let traits = appearance.traitCollection

            #expect(UIColor(named: "AccentColor", in: .main, compatibleWith: traits) == nil)

            for name in contract.roles.keys.sorted() {
                let actual = try resolvedComponents(named: name, traits: traits)
                let expected = try contract.components(for: name, appearance: appearance)

                #expect(actual.isApproximatelyEqual(to: expected), "\(name) differs in \(appearance.rawValue)")
            }
        }
    }

    @Test("Every authorized pair meets its unrounded contrast target")
    func authorizedPairsMeetTargets() throws {
        let contract = try LibraryColorContract.load()
        let pairs = contract.authorizedPairs

        #expect(pairs.count == contract.auditMethod.semanticPairsPerMode)

        var evaluatedPairCount = 0

        for appearance in LibraryAppearance.allCases {
            let mode = try contract.mode(for: appearance)

            for pair in pairs {
                let foreground = try resolvedComponents(named: pair.foreground, traits: appearance.traitCollection)
                let background = try resolvedComponents(named: pair.background, traits: appearance.traitCollection)
                let ratio = foreground.contrastRatio(with: background)
                let target = pair.kind == .text ? mode.textTarget : mode.nonTextTarget

                #expect(
                    ratio >= target,
                    "\(pair.foreground) / \(pair.background) is below \(target):1 in \(appearance.rawValue)"
                )
                evaluatedPairCount += 1
            }
        }

        #expect(evaluatedPairCount == contract.auditMethod.semanticPairsTotal)
    }

    private func resolvedComponents(named name: String, traits: UITraitCollection) throws -> SRGBComponents {
        let dynamicColor = try #require(
            UIColor(named: name, in: .main, compatibleWith: traits),
            "Missing compiled color \(name)"
        )
        let color = dynamicColor.resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            throw LibraryColorTestError.notRGB(name)
        }

        return SRGBComponents(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
    }
}

private enum LibraryAppearance: String, CaseIterable {
    case light
    case dark
    case highContrastLight
    case highContrastDark

    var assetTraits: [String: String] {
        switch self {
        case .light:
            [:]
        case .dark:
            ["luminosity": "dark"]
        case .highContrastLight:
            ["contrast": "high"]
        case .highContrastDark:
            [
                "contrast": "high",
                "luminosity": "dark"
            ]
        }
    }

    @MainActor
    var traitCollection: UITraitCollection {
        let style: UIUserInterfaceStyle = switch self {
        case .light, .highContrastLight: .light
        case .dark, .highContrastDark: .dark
        }
        let contrast: UIAccessibilityContrast = switch self {
        case .light, .dark: .normal
        case .highContrastLight, .highContrastDark: .high
        }

        let environment = UIView()
        environment.traitOverrides.userInterfaceStyle = style
        environment.traitOverrides.accessibilityContrast = contrast
        environment.updateTraitsIfNeeded()
        return environment.traitCollection
    }
}

private struct LibraryColorContract: Decodable {
    struct Mode: Decodable {
        struct ColorValue: Decodable {
            let hex: String
        }

        let textTarget: Double
        let nonTextTarget: Double
        let colors: [String: ColorValue]
    }

    struct PairGroup: Decodable {
        let kind: PairKind
        let foregrounds: [String]?
        let backgrounds: [String]?
        let explicitPairs: [[String]]?
    }

    struct AuditMethod: Decodable {
        let semanticPairsPerMode: Int
        let semanticPairsTotal: Int
    }

    let roles: [String: String]
    let modes: [String: Mode]
    let allowedPairGroups: [PairGroup]
    let auditMethod: AuditMethod

    static let repositoryURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func load() throws -> Self {
        let url = repositoryURL.appending(path: "docs/design/library-color-tokens.json")
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    var authorizedPairs: [AuthorizedPair] {
        allowedPairGroups.flatMap { group in
            let cartesianPairs = (group.foregrounds ?? []).flatMap { foreground in
                (group.backgrounds ?? []).map { background in
                    AuthorizedPair(kind: group.kind, foreground: foreground, background: background)
                }
            }
            let explicitPairs: [AuthorizedPair] = (group.explicitPairs ?? []).compactMap { pair in
                guard pair.count == 2 else { return nil }
                return AuthorizedPair(kind: group.kind, foreground: pair[0], background: pair[1])
            }

            return cartesianPairs + explicitPairs
        }
    }

    func mode(for appearance: LibraryAppearance) throws -> Mode {
        guard let mode = modes[appearance.rawValue] else {
            throw LibraryColorTestError.missingMode(appearance.rawValue)
        }
        return mode
    }

    func components(for role: String, appearance: LibraryAppearance) throws -> SRGBComponents {
        guard let sourceName = roles[role] else { throw LibraryColorTestError.missingRole(role) }
        let mode = try mode(for: appearance)
        guard let value = mode.colors[sourceName] else { throw LibraryColorTestError.missingColor(sourceName) }
        return try SRGBComponents(hex: value.hex)
    }
}

private enum PairKind: String, Decodable {
    case text
    case nonText
}

private struct AuthorizedPair {
    let kind: PairKind
    let foreground: String
    let background: String
}

private struct ColorAsset: Decodable {
    struct Entry: Decodable {
        struct Appearance: Decodable {
            let appearance: String
            let value: String
        }

        let appearances: [Appearance]?
        let color: ColorDefinition
        let idiom: String

        var traits: [String: String] {
            Dictionary(
                uniqueKeysWithValues: (appearances ?? []).map {
                    ($0.appearance, $0.value)
                }
            )
        }
    }

    let colors: [Entry]
}

private struct ColorDefinition: Decodable {
    struct Components: Decodable {
        let alpha: String
        let blue: String
        let green: String
        let red: String
    }

    let colorSpace: String
    let components: Components

    private enum CodingKeys: String, CodingKey {
        case colorSpace = "color-space"
        case components
    }

    func sRGBComponents() throws -> SRGBComponents {
        SRGBComponents(
            red: try Self.component(components.red),
            green: try Self.component(components.green),
            blue: try Self.component(components.blue),
            alpha: try Self.component(components.alpha)
        )
    }

    private static func component(_ value: String) throws -> Double {
        if value.hasPrefix("0x"),
           let byte = UInt8(value.dropFirst(2), radix: 16) {
            return Double(byte) / 255
        }
        guard let component = Double(value) else { throw LibraryColorTestError.invalidComponent(value) }
        return component
    }
}

private struct SRGBComponents: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    func isApproximatelyEqual(to other: Self) -> Bool {
        let tolerance = 0.5 / 255
        return abs(red - other.red) < tolerance
            && abs(green - other.green) < tolerance
            && abs(blue - other.blue) < tolerance
            && abs(alpha - other.alpha) < tolerance
    }

    func contrastRatio(with other: Self) -> Double {
        let foreground = relativeLuminance
        let background = other.relativeLuminance
        return (max(foreground, background) + 0.05)
            / (min(foreground, background) + 0.05)
    }

    private var relativeLuminance: Double {
        0.2126 * Self.linearized(red)
            + 0.7152 * Self.linearized(green)
            + 0.0722 * Self.linearized(blue)
    }

    private static func linearized(_ component: Double) -> Double {
        if component <= 0.04045 {
            return component / 12.92
        }
        return pow((component + 0.055) / 1.055, 2.4)
    }
}

private extension SRGBComponents {
    init(hex: String) throws {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            throw LibraryColorTestError.invalidHex(hex)
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

private enum LibraryColorTestError: Error {
    case invalidComponent(String)
    case invalidHex(String)
    case missingColor(String)
    case missingMode(String)
    case missingRole(String)
    case notRGB(String)
}
