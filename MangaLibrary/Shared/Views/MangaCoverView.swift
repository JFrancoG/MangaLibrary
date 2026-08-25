//
//  MangaCoverView.swift
//  MangaLibrary
//

import Foundation
import SwiftUI

struct MangaCoverView: View {
    private let url: URL?
    private let previewPhase: AsyncImagePhase?

    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 88

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
        .frame(width: min(width, 96), height: min(height, 132))
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
}

extension MangaCoverView {
    init(url: URL?) {
        self.url = url
        previewPhase = nil
    }

    init(previewPhase: AsyncImagePhase) {
        url = nil
        self.previewPhase = previewPhase
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
