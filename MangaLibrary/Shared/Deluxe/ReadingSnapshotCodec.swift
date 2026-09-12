//
//  ReadingSnapshotCodec.swift
//  MangaLibrary
//

import CryptoKit
import Foundation

/// Bounds UTF-8 input before decoding and writes the compact, deterministic Deluxe wire representation.
///
/// The JSON limit and the complete WatchConnectivity context budget are separate checks. A publisher
/// must also measure the binary plist context before committing a transportable projection.
enum ReadingSnapshotCodec {
    static let maximumByteCount = 32_768
    static let maximumContextByteCount = 32_768

    static func encode(_ snapshot: ReadingSnapshot) throws -> Data {
        try encodedData(snapshot)
    }

    static func decode(_ data: Data) throws -> ReadingSnapshot {
        try decodedValue(ReadingSnapshot.self, from: data)
    }

    static func encodeFence(_ fence: SessionFence) throws -> Data {
        try encodedData(fence)
    }

    static func decodeFence(_ data: Data) throws -> SessionFence {
        try decodedValue(SessionFence.self, from: data)
    }

    /// Includes dictionary framing in the byte count without claiming WatchConnectivity will accept the payload.
    static func contextByteCount(for data: Data) throws -> Int {
        try PropertyListSerialization.data(
            fromPropertyList: ["readingSnapshot": data],
            format: .binary,
            options: 0
        ).count
    }

    private static func encodedData(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard data.count <= maximumByteCount else { throw ReadingSnapshotError.payloadTooLarge }
        return data
    }

    private static func decodedValue<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        guard data.count <= maximumByteCount else { throw ReadingSnapshotError.payloadTooLarge }
        guard String(data: data, encoding: .utf8) != nil else { throw ReadingSnapshotError.invalidUTF8 }
        return try JSONDecoder().decode(type, from: data)
    }
}

/// Keeps the complete local resource bounded and deterministic; it never selects a partial collection.
enum CollectionWidgetSnapshotCodec {
    static let maximumByteCount = 1_048_576
    static let maximumItemCount = 4_096

    static func encode(_ snapshot: CollectionWidgetSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(snapshot)
        guard data.count <= maximumByteCount else { throw CollectionWidgetSnapshotError.payloadTooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> CollectionWidgetSnapshot {
        guard data.count <= maximumByteCount else { throw CollectionWidgetSnapshotError.payloadTooLarge }
        guard String(data: data, encoding: .utf8) != nil else { throw CollectionWidgetSnapshotError.invalidUTF8 }
        return try JSONDecoder().decode(CollectionWidgetSnapshot.self, from: data)
    }

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    static func matches(_ data: Data, reference: CollectionWidgetSnapshot.Reference) -> Bool {
        guard data.count == reference.byteCount, data.count <= maximumByteCount else { return false }
        return digest(data) == reference.digest
    }
}
