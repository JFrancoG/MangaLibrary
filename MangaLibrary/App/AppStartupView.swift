import SwiftUI

struct AppStartupView: View {
    let model: AppStartupModel

    var body: some View {
        Group {
            switch model.state {
            case .idle, .opening:
                AppStartupLoadingView()
            case .unavailable:
                AppStartupUnavailableView(retry: model.retry)
            case let .ready(runtime):
                AppReadyView(runtime: runtime)
            }
        }
        .task {
            await model.startIfNeeded()
        }
    }
}

#if DEBUG
#Preview("Startup recovery") {
    @Previewable @State var model = UITestingBootstrap.makeIfRequested(
        processArguments: ["-ui-testing", "-ui-testing-startup-recovery"]
    )
    if let model {
        AppStartupView(model: model)
    }
}
#endif
