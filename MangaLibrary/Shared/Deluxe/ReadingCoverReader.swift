import Darwin
import Foundation

/// Reads only validated, bounded JPEG resources beneath the approved shared root.
///
/// Directory descriptors and no-follow opens keep a replaced covers directory or
/// symbolic link from redirecting a read outside that root. Any incompatibility
/// or unavailable file is an optional-image failure and produces a placeholder.
struct ReadingCoverReader {
    private let directoryURL: URL

    func read(_ identifier: String) -> ReadingCoverResource? {
        guard directoryURL.isFileURL, ReadingCoverResource.isValidIdentifier(identifier) else { return nil }
        let root = open(directoryURL.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard root >= 0 else { return nil }
        defer { close(root) }
        let covers = openat(root, "covers", O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard covers >= 0 else { return nil }
        defer { close(covers) }
        let file = openat(covers, identifier + ".jpg", O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard file >= 0 else { return nil }
        defer { close(file) }

        guard
            let data = try? ReadingCoverFileAccess.read(fileDescriptor: file, limit: 65_536),
            let resource = ReadingCoverResource(jpegData: data),
            resource.identifier == identifier
        else { return nil }
        return resource
    }
}

extension ReadingCoverReader {
    init(sharedDirectory: URL) {
        directoryURL = sharedDirectory.standardizedFileURL
    }
}

/// Shared bounded-file mechanics; callers retain ownership of the opened descriptor.
enum ReadingCoverFileAccess {
    static func read(fileDescriptor: Int32, limit: Int) throws -> Data {
        var information = stat()
        guard
            fstat(fileDescriptor, &information) == 0,
            information.st_mode & S_IFMT == S_IFREG,
            information.st_size >= 0,
            information.st_size <= limit
        else { throw CocoaError(.fileReadCorruptFile) }
        let handle = FileHandle(fileDescriptor: fileDescriptor, closeOnDealloc: false)
        var bytes = Data()
        while bytes.count <= limit {
            guard let chunk = try handle.read(upToCount: limit + 1 - bytes.count), !chunk.isEmpty else { break }
            bytes.append(chunk)
        }
        guard bytes.count <= limit else { throw CocoaError(.fileReadTooLarge) }
        return bytes
    }
}
