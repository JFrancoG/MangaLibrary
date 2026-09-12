import Foundation
import Synchronization

#if os(iOS) || os(watchOS)
import os
import WatchConnectivity
#endif

enum WatchReadingConnectivityError: Error, Equatable {
    case invalidContext
    case payloadTooLarge
    case notActivated
    case deliveryFailed
    case consumerAlreadyRunning
}

enum WatchReadingContext {
    static let key = "readingSnapshot"

    static func validatedData(from context: [String: Any]) throws -> Data {
        guard context.count == 1, let data = context[key] as? Data else {
            throw WatchReadingConnectivityError.invalidContext
        }
        try validate(data)
        return data
    }

    static func validate(_ data: Data) throws {
        guard data.count <= ReadingSnapshotCodec.maximumByteCount else {
            throw WatchReadingConnectivityError.payloadTooLarge
        }
        guard try ReadingSnapshotCodec.contextByteCount(for: data) <= ReadingSnapshotCodec.maximumContextByteCount else {
            throw WatchReadingConnectivityError.payloadTooLarge
        }
    }
}

#if os(iOS) || os(watchOS)
/// Converts native serial callbacks to ordered values consumed by one structured task.
///
/// This adapter owns every application access to the default session under its mutex; the
/// session and untyped dictionaries never cross into an async consumer. The publisher retains
/// authority over pending content and revalidates it when activation permits another attempt.
final class WatchReadingConnectivity: NSObject, WCSessionDelegate, Sendable {
    enum Event: Equatable {
        case activated
        case received(Data)
        case invalidContext
        case unavailable
        case contentDrained
        case requestedContentDrained(UUID)
    }

    private struct SessionState {
        var session: WCSession?
        var pendingObservation: NSKeyValueObservation?
        var drainRequests: [UUID] = []
    }

    private let events = WatchReadingEventQueue()
    private let sessionState = Mutex(SessionState())

    #if DEBUG
    private static let logger = Logger(subsystem: "com.plusprojects.MangaLibrary", category: "WatchReadingConnectivity")
    #endif

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        sessionState.withLock { state in
            state.session = WCSession.default
            state.session?.delegate = self
            state.pendingObservation = state.session?.observe(\.hasContentPending, options: [.new]) {
                [weak self] _, change in
                if change.newValue == false {
                    self?.events.requestDrainCheck()
                }
            }
        }
    }

    func activate() {
        sessionState.withLock { state in
            guard let session = state.session, session.activationState == .notActivated else { return }
            session.activate()
        }
    }

    var hasContentPending: Bool { sessionState.withLock { $0.session?.hasContentPending ?? false } }

    /// Reattempts activation and queues a drain check behind earlier callback values.
    func requestContentDrain() {
        activate()
        events.requestDrainCheck()
    }

    /// Correlates completion to this request, so a previously queued terminal cannot finish it.
    func requestContentDrain(_ identity: UUID) {
        activate()
        events.requestDrainCheck(identity)
    }

    /// Requests replacement synchronously, independently of counterpart reachability.
    ///
    /// An accepted call is not delivery evidence. Failures, including the framework's own size
    /// rejection below the application budget, leave canonical publication and logout intact.
    func send(_ data: Data) throws {
        try WatchReadingContext.validate(data)
        try sessionState.withLock { state in
            guard let session = state.session else { return }
            guard session.activationState == .activated else { throw WatchReadingConnectivityError.notActivated }
            do {
                try session.updateApplicationContext([WatchReadingContext.key: data])
                #if DEBUG
                Self.logger.debug("Reading context accepted by WCSession: \(data.count, privacy: .public) bytes")
                #endif
            } catch {
                let error = error as NSError
                if error.domain == WCErrorDomain, error.code == WCError.Code.payloadTooLarge.rawValue {
                    throw WatchReadingConnectivityError.payloadTooLarge
                }
                throw WatchReadingConnectivityError.deliveryFailed
            }
        }
    }

    /// Owns one serial consumer until cancellation; scene inactivity alone must not end it.
    ///
    /// The system's latest received context is replayed after activation and on consumer restart.
    /// Receiver idempotency handles that replay. The caller must keep processing and persisting
    /// while its process runs in the background, without depending on presentation being active.
    func run(untilContentDrained: Bool = false, receive: @Sendable (Event) async -> Void) async throws {
        guard sessionState.withLock({ $0.session != nil }) else { return }
        try await events.run(
            untilContentDrained: untilContentDrained,
            prepare: {
                let activated = self.sessionState.withLock { $0.session?.activationState == .activated }
                if activated {
                    self.recordActivation()
                }
                self.activate()
            },
            checkContentDrain: {
                self.enqueueContentDrain($0)
            },
            receive: receive
        )
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        guard activationState == .activated, error == nil else {
            sessionState.withLock { state in
                state.drainRequests.removeAll()
                record(.unavailable)
            }
            return
        }
        #if DEBUG
        Self.logger.debug("WCSession activated")
        #endif
        recordActivation()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        #if DEBUG
        Self.logger.debug("WCSession delivered an application-context delegate callback")
        #endif
        // A callback argument can lag behind a newer native context already captured by another path.
        // Capturing and enqueueing the current property under one lock keeps those observations ordered.
        sessionState.withLock { state in
            guard let session = state.session else { return }
            record(Self.contextEvent(session.receivedApplicationContext))
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        sessionState.withLock { state in
            state.drainRequests.removeAll()
            record(.unavailable)
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        let activated = sessionState.withLock { $0.session?.activationState == .activated }
        if activated {
            record(.activated)
        }
    }
    #endif

    private func record(_ event: Event) {
        events.record(event)
    }

    private func recordActivation() {
        sessionState.withLock { state in
            guard let session = state.session, session.activationState == .activated else { return }
            record(.activated)
            recordCurrentContext(session)
            recordDrainIfComplete(&state)
        }
    }

    private func enqueueContentDrain(_ identity: UUID?) {
        sessionState.withLock { state in
            if let identity, !state.drainRequests.contains(identity) {
                state.drainRequests.append(identity)
            }
            guard let session = state.session, session.activationState == .activated else { return }
            guard !session.hasContentPending else { return }
            recordCurrentContext(session)
            recordDrainIfComplete(&state)
        }
    }

    private func recordCurrentContext(_ session: WCSession) {
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            record(Self.contextEvent(context))
        }
    }

    private func recordDrainIfComplete(_ state: inout SessionState) {
        guard state.session?.hasContentPending == false else { return }
        record(.contentDrained)
        for identity in state.drainRequests {
            record(.requestedContentDrained(identity))
        }
        state.drainRequests.removeAll()
    }

    private static func contextEvent(_ context: [String: Any]) -> Event {
        do {
            let data = try WatchReadingContext.validatedData(from: context)
            #if DEBUG
            logger.debug("Reading context available from WCSession: \(data.count, privacy: .public) bytes")
            #endif
            return .received(data)
        } catch {
            #if DEBUG
            logger.debug("WCSession reading context rejected at its format boundary")
            #endif
            return .invalidContext
        }
    }
}

/// Delivers captured values serially while keeping consumer ownership through cancellation.
/// A drain check appends its captured context and terminal after queued values; consumers never reread live state.
final class WatchReadingEventQueue: Sendable {
    private final class DeliveryVersion: Sendable {}

    private struct Input {
        enum Kind {
            case event(WatchReadingConnectivity.Event)
            case drainRequested(UUID?)
        }

        let kind: Kind
        let deliveryVersion: DeliveryVersion?
    }

    private struct State {
        var consumer: UUID?
        var continuation: AsyncStream<Input>.Continuation?
        var latestContent: WatchReadingConnectivity.Event?
        var latestAvailability: Bool?
        var deliveryVersion: DeliveryVersion?
    }

    private let state = Mutex(State())

    func record(_ event: WatchReadingConnectivity.Event) {
        state.withLock { state in
            guard let continuation = state.continuation else { return }
            switch event {
            case .received, .invalidContext:
                if state.latestContent != event {
                    state.latestContent = event
                    state.deliveryVersion = DeliveryVersion()
                }
            case .activated:
                if state.latestAvailability != true {
                    state.latestAvailability = true
                    state.deliveryVersion = DeliveryVersion()
                }
            case .unavailable:
                if state.latestAvailability != false {
                    state.latestAvailability = false
                    state.deliveryVersion = DeliveryVersion()
                }
            case .contentDrained, .requestedContentDrained:
                break
            }
            continuation.yield(Input(kind: .event(event), deliveryVersion: state.deliveryVersion))
        }
    }

    func requestDrainCheck(_ identity: UUID? = nil) {
        _ = state.withLock { state in
            state.continuation?.yield(Input(kind: .drainRequested(identity), deliveryVersion: state.deliveryVersion))
        }
    }

    func run(
        untilContentDrained: Bool = false,
        prepare: @Sendable () -> Void,
        checkContentDrain: @Sendable (UUID?) -> Void,
        receive: @Sendable (WatchReadingConnectivity.Event) async -> Void
    ) async throws {
        try Task.checkCancellation()
        let pair = AsyncStream<Input>.makeStream(bufferingPolicy: .unbounded)
        let identity = UUID()
        try state.withLock { state in
            guard state.consumer == nil else { throw WatchReadingConnectivityError.consumerAlreadyRunning }
            state.consumer = identity
            state.continuation = pair.continuation
        }
        defer { release(identity) }
        prepare()
        if untilContentDrained {
            checkContentDrain(identity)
        }
        for await input in pair.stream {
            try Task.checkCancellation()
            if case let .drainRequested(identity) = input.kind {
                checkContentDrain(identity)
                continue
            }
            guard case let .event(event) = input.kind else { continue }
            switch event {
            case .contentDrained, .requestedContentDrained:
                guard isCurrent(input) else {
                    rearm(event, checkContentDrain: checkContentDrain)
                    continue
                }
            case .unavailable:
                guard isCurrent(input) else {
                    rearmUnavailable(
                        identity: untilContentDrained ? identity : nil,
                        checkContentDrain: checkContentDrain
                    )
                    continue
                }
            case .activated, .received, .invalidContext:
                break
            }
            await receive(event)
            try Task.checkCancellation()
            guard untilContentDrained else { continue }
            switch event {
            case .unavailable:
                if finishIfCurrent(input, identity: identity) {
                    return
                }
                rearmUnavailable(identity: identity, checkContentDrain: checkContentDrain)
            case let .requestedContentDrained(requestedIdentity) where requestedIdentity == identity:
                if finishIfCurrent(input, identity: identity) {
                    return
                }
                checkContentDrain(identity)
            case .activated, .received, .invalidContext, .contentDrained, .requestedContentDrained:
                break
            }
        }
        try Task.checkCancellation()
    }

    private func isCurrent(_ input: Input) -> Bool { state.withLock { $0.deliveryVersion === input.deliveryVersion } }

    private func rearm(
        _ event: WatchReadingConnectivity.Event,
        checkContentDrain: @Sendable (UUID?) -> Void
    ) {
        switch event {
        case .contentDrained:
            checkContentDrain(nil)
        case let .requestedContentDrained(identity):
            checkContentDrain(identity)
        case .activated, .received, .invalidContext, .unavailable:
            break
        }
    }

    private func rearmUnavailable(identity: UUID?, checkContentDrain: @Sendable (UUID?) -> Void) {
        let shouldCheckNative = state.withLock { state in
            guard let continuation = state.continuation else { return false }
            if state.latestAvailability == false {
                continuation.yield(Input(kind: .event(.unavailable), deliveryVersion: state.deliveryVersion))
                return false
            }
            return true
        }
        if shouldCheckNative {
            checkContentDrain(identity)
        }
    }

    /// Closes the lease atomically against context or activation changes during its terminal suspension.
    private func finishIfCurrent(_ input: Input, identity: UUID) -> Bool {
        let continuation: AsyncStream<Input>.Continuation? = state.withLock { state in
            guard state.consumer == identity, state.deliveryVersion === input.deliveryVersion else { return nil }
            let continuation = state.continuation
            state.consumer = nil
            state.continuation = nil
            state.latestContent = nil
            state.latestAvailability = nil
            state.deliveryVersion = nil
            return continuation
        }
        guard let continuation else { return false }
        continuation.finish()
        return true
    }

    private func release(_ identity: UUID) {
        let continuation: AsyncStream<Input>.Continuation? = state.withLock { state in
            guard state.consumer == identity else { return nil }
            let continuation = state.continuation
            state.consumer = nil
            state.continuation = nil
            state.latestContent = nil
            state.latestAvailability = nil
            state.deliveryVersion = nil
            return continuation
        }
        continuation?.finish()
    }
}
#endif
