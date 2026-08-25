//
//  Manga.swift
//  MangaLibrary
//

import Foundation

struct Manga: Identifiable, Equatable {
    let id: Int64
    let title: String
    let titleEnglish: String?
    let titleJapanese: String?
    let synopsis: String?
    let score: Double
    let coverURL: URL?
}
