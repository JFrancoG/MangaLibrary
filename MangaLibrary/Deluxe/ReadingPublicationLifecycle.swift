import Foundation
import Observation

/// Shares one structured publication consumer across the app's scene-owned tasks.
///
/// A scene disappearance releases ownership only after its pipeline has drained. The wake
/// identity then lets another active scene compete. A failed retirement remains visible until
/// an explicit retry; it never becomes an automatic restart loop or an orphaned task.
@Observable @MainActor
final class ReadingPublicationLifecycle {
    struct Failure {
        let identity: UUID
        let authority: SessionAuthority?
        let underlyingError: any Error
    }

    private(set) var wakeID: UUID
    private(set) var failure: Failure?

    @ObservationIgnored private var running = false
    @ObservationIgnored private let runPipeline: @Sendable () async throws -> Void
    @ObservationIgnored private let makeIdentity: () -> UUID

    init(
        runPipeline: @escaping @Sendable () async throws -> Void,
        makeIdentity: @escaping () -> UUID = { UUID() }
    ) {
        self.runPipeline = runPipeline
        self.makeIdentity = makeIdentity
        wakeID = makeIdentity()
    }

    func run() async {
        guard !Task.isCancelled, !running, failure == nil else { return }
        running = true
        var shouldWake = false
        defer {
            running = false
            if shouldWake {
                wakeID = makeIdentity()
            }
        }

        do {
            try await runPipeline()
            try Task.checkCancellation()
        } catch let error as ReadingPublicationSessionReconciliationError {
            failure = Failure(
                identity: makeIdentity(),
                authority: error.authority,
                underlyingError: error.underlyingError
            )
        } catch is CancellationError {
            shouldWake = true
        } catch {
            failure = Failure(identity: makeIdentity(), authority: nil, underlyingError: error)
        }
    }

    func retry() {
        guard !running, failure != nil else { return }
        failure = nil
        wakeID = makeIdentity()
    }
}
