import SwiftUI

struct WatchReadingStateView: View {
    enum State {
        case empty
        case redacted
        case unavailable
    }

    let state: State

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.brandPrimaryInk)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(.textPrimary)
            Text(message)
                .font(.body)
                .foregroundStyle(.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch state {
        case .empty: "book"
        case .redacted: "books.vertical"
        case .unavailable: "iphone"
        }
    }

    private var title: LocalizedStringResource {
        switch state {
        case .empty: "What are you reading?"
        case .redacted: "Your manga, right here"
        case .unavailable: "Let's refresh"
        }
    }

    private var message: LocalizedStringResource {
        switch state {
        case .empty: "Set your current volume in Manga Library on your iPhone."
        case .redacted: "Sign in to Manga Library on your iPhone."
        case .unavailable: "Open Manga Library on your iPhone to bring your readings here."
        }
    }
}

#Preview("Redacted · ES · AX 5") {
    List {
        WatchReadingStateView(state: .redacted)
            .listRowBackground(Color.surface)
    }
    .environment(\.locale, Locale(identifier: "es"))
    .environment(\.dynamicTypeSize, .accessibility5)
}
