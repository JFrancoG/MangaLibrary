import SwiftUI

struct ReadingPublicationNoticeView: View {
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The widget could not update your readings.")
                .font(.callout)
                .foregroundStyle(.textPrimary)
            Button("Try again") {
                retry()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.surfaceStrong)
        .accessibilityIdentifier("reading.publication.failure")
    }
}

#Preview("Publication unavailable") {
    ReadingPublicationNoticeView {}
}

#Preview("Publication unavailable · AX 5") {
    ReadingPublicationNoticeView {}
        .environment(\.dynamicTypeSize, .accessibility5)
        .environment(\.locale, Locale(identifier: "es"))
}
