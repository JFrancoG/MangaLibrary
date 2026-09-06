import Foundation
import Synchronization

enum ReadingPublicationPipelineError: Error, Equatable {
    case consumerAlreadyRunning
}

/// Invalidated synchronously when a later committed Collection state replaces this intent.
///
/// Call `validate(authority:)` inside the matching session commit boundary. The ticket contains
/// no Collection data and does not retain its event source or an asynchronous consumer.
final class ReadingPublicationTicket: Sendable {
    private let authority: SessionAuthority
    private let valid = Mutex(true)

    fileprivate init(authority: SessionAuthority) {
        self.authority = authority
    }

    func validate(authority: SessionAuthority) throws {
        guard self.authority == authority, valid.withLock({ $0 }) else {
            throw ReadingPublicationError.staleProjection
        }
    }

    fileprivate func invalidate() {
        valid.withLock { $0 = false }
    }
}

struct ReadingPublicationEvent {
    let authorization: SessionCommitAuthorization
    let ticket: ReadingPublicationTicket
}

/// Retains only the latest intent, independently of any particular consumer lifetime.
///
/// Record committed changes while their session gate is held. A single lease owns delivery;
/// consumers release it only after their in-flight preparation has ended. Stream termination
/// alone never releases that ownership, and finishing occurs outside this source's lock.
final class ReadingPublicationEvents: Sendable {
    struct Subscription {
        fileprivate let identity: UUID
        let stream: AsyncStream<ReadingPublicationEvent>
    }

    private struct State {
        var latest: ReadingPublicationEvent?
        var subscriber: UUID?
        var continuation: AsyncStream<ReadingPublicationEvent>.Continuation?
    }

    private let state = Mutex(State())

    @discardableResult
    func record(authorization: SessionCommitAuthorization) -> ReadingPublicationEvent {
        state.withLock { state in
            state.latest?.ticket.invalidate()
            let event = ReadingPublicationEvent(
                authorization: authorization,
                ticket: ReadingPublicationTicket(authority: authorization.authority)
            )
            state.latest = event
            state.continuation?.yield(event)
            return event
        }
    }

    func invalidate(authority: SessionAuthority) {
        state.withLock { state in
            guard state.latest?.authorization.authority == authority else { return }
            state.latest?.ticket.invalidate()
            state.latest = nil
        }
    }

    func currentEvent() -> ReadingPublicationEvent? { state.withLock { $0.latest } }

    func subscribe() throws -> Subscription {
        let pair = AsyncStream<ReadingPublicationEvent>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let identity = UUID()
        do {
            try state.withLock { state in
                guard state.subscriber == nil else { throw ReadingPublicationPipelineError.consumerAlreadyRunning }
                state.subscriber = identity
                state.continuation = pair.continuation
                if let latest = state.latest {
                    pair.continuation.yield(latest)
                }
            }
            return Subscription(identity: identity, stream: pair.stream)
        } catch {
            pair.continuation.finish()
            throw error
        }
    }

    func release(_ subscription: Subscription) {
        let continuation: AsyncStream<ReadingPublicationEvent>.Continuation? = state.withLock { state in
            guard state.subscriber == subscription.identity else { return nil }
            let continuation = state.continuation
            state.subscriber = nil
            state.continuation = nil
            return continuation
        }
        continuation?.finish()
    }
}
