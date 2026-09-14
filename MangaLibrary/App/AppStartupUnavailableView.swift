import SwiftUI

struct AppStartupUnavailableView: View {
    let retry: @MainActor () async -> Void

    var body: some View {
        ScrollView {
            ContentUnavailableView {
                Label("Your library couldn’t be opened", systemImage: "books.vertical")
                    .foregroundStyle(.textPrimary)
                    .accessibilityIdentifier("startup.unavailable")
            } description: {
                Text("Try again to open your saved library.")
                    .foregroundStyle(.textSecondary)
            } actions: {
                Button {
                    Task {
                        await retry()
                    }
                } label: {
                    Text("Try again")
                        .foregroundStyle(.onBrandPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPrimary)
                .controlSize(.large)
                .accessibilityIdentifier("startup.retry")
            }
        }
        .defaultScrollAnchor(.center, for: .alignment)
        .background(.canvas)
    }
}

#Preview("Startup unavailable · English") {
    AppStartupUnavailableView {}
        .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Startup unavailable · Español") {
    AppStartupUnavailableView {}
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Startup unavailable · Español · AX 5") {
    AppStartupUnavailableView {}
        .environment(\.locale, Locale(identifier: "es"))
        .environment(\.dynamicTypeSize, .accessibility5)
}
