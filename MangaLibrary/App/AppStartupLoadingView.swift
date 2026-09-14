import SwiftUI

struct AppStartupLoadingView: View {
    var body: some View {
        ProgressView {
            Text("Opening your library")
                .foregroundStyle(.textSecondary)
        }
        .tint(.textSecondary)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.canvas)
    }
}

#Preview("Opening library · Español") {
    AppStartupLoadingView()
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Opening library · English · AX 5") {
    AppStartupLoadingView()
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .accessibility5)
}
