import Foundation

/// The app is the only writer; the extension resolves this same group without a private fallback.
enum ReadingWidgetBridge {
    static let groupIdentifier = "group.com.plusprojects.MangaLibrary.deluxe"
    static let kind = "com.plusprojects.MangaLibrary.reading"

    static func sharedDirectory() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
            .appending(path: "Reading", directoryHint: .isDirectory)
    }
}
