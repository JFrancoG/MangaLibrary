//
//  MangaCoverView.swift
//  MangaLibrary
//

import Foundation
import SwiftUI

struct MangaCoverView: View {
    enum Presentation {
        case row
        case grid
    }

    private let url: URL?
    private let previewPhase: AsyncImagePhase?
    private let presentation: Presentation

    @ScaledMetric(relativeTo: .body) private var rowWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 88
    @ScaledMetric(relativeTo: .body) private var gridWidth: CGFloat = 104
    @ScaledMetric(relativeTo: .body) private var gridHeight: CGFloat = 143

    var body: some View {
        Group {
            if let previewPhase {
                cover(for: previewPhase)
            } else if let url {
                AsyncImage(url: url) { phase in
                    cover(for: phase)
                }
            } else {
                unavailableCover
            }
        }
        .frame(width: size.width, height: size.height)
        .background(.fill.tertiary)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cover(for phase: AsyncImagePhase) -> some View {
        switch phase {
        case let .success(image):
            image
                .resizable()
                .scaledToFill()
        case .empty:
            ProgressView()
        case .failure:
            unavailableCover
        @unknown default:
            unavailableCover
        }
    }

    private var unavailableCover: some View {
        Image(systemName: "book.closed")
            .font(.title2)
            .foregroundStyle(.secondary)
    }

    private var size: CGSize {
        switch presentation {
        case .row:
            CGSize(width: min(rowWidth, 96), height: min(rowHeight, 132))
        case .grid:
            CGSize(width: min(gridWidth, 160), height: min(gridHeight, 220))
        }
    }
}

extension MangaCoverView {
    init(url: URL?, presentation: Presentation = .row) {
        self.url = url
        previewPhase = nil
        self.presentation = presentation
    }

    init(previewPhase: AsyncImagePhase) {
        url = nil
        self.previewPhase = previewPhase
        presentation = .row
    }
}

#Preview("Cover unavailable") {
    MangaCoverView(url: nil)
        .padding()
}

#Preview("Cover failure") {
    MangaCoverView(previewPhase: .failure(URLError(.cannotDecodeContentData)))
        .padding()
}

#Preview("Grid cover") {
    MangaCoverView(url: nil, presentation: .grid)
        .padding()
}
