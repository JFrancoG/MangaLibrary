import Observation
import SwiftData

/// Owns storage opening for the app, independently of any window's lifetime.
@Observable
@MainActor
final class AppStartupModel {
    enum State {
        case idle
        case opening
        case unavailable
        case ready(AppRuntime)
    }

    private(set) var state = State.idle
    private let openStore: @Sendable () async throws -> ModelContainer
    private let compose: @MainActor (ModelContainer) -> AppRuntime

    init(
        openStore: @escaping @Sendable () async throws -> ModelContainer,
        compose: @escaping @MainActor (ModelContainer) -> AppRuntime
    ) {
        self.openStore = openStore
        self.compose = compose
    }

    /// Scene reentry never retries a failure or replaces a successful composition.
    func startIfNeeded() async {
        guard case .idle = state else { return }
        await open()
    }

    func retry() async {
        guard case .unavailable = state else { return }
        await open()
    }

    private func open() async {
        state = .opening

        // This finite task belongs to the app. Cancelling a scene's waiter must not
        // cancel an opening that another scene needs, or leave startup stranded.
        let opening = Task {
            do {
                let container = try await openStore()
                state = .ready(compose(container))
            } catch {
                state = .unavailable
            }
        }
        await opening.value
    }
}
