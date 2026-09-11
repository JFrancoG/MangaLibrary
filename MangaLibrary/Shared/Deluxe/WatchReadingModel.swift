import Foundation
import Observation

#if os(iOS) || os(watchOS)
/// Keeps one structured receiver active across presentation and watch background launches.
///
/// The native adapter reconciles its latest context in callback order before a drain terminal.
/// A restored disk cache is not displayed before reconciliation or a temporary activation failure.
/// The latter retains compatible offline data without asserting current iPhone authorization.
/// Each background request waits for its own terminal; cancellation releases its waiting signal.
@Observable @MainActor
final class WatchReadingModel {
    struct Connection {
        let run: @Sendable (Bool, @Sendable (WatchReadingConnectivity.Event) async -> Void) async throws -> Void
        let requestContentDrain: @Sendable (UUID) -> Void
    }

    private(set) var snapshot: ReadingSnapshot?
    private(set) var isTemporarilyUnavailable = false
    private let receiver: WatchReadingSnapshotReceiver
    private let connection: Connection
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var hasReceivedContext = false
    @ObservationIgnored private var drainWaiters: [UUID: AsyncStream<Bool>.Continuation] = [:]
    @ObservationIgnored private var releaseWaiters: [UUID: AsyncStream<Void>.Continuation] = [:]

    init(receiver: WatchReadingSnapshotReceiver, connection: Connection) {
        self.receiver = receiver
        self.connection = connection
    }

    convenience init(receiver: WatchReadingSnapshotReceiver, connectivity: WatchReadingConnectivity) {
        self.init(
            receiver: receiver,
            connection: Connection(
                run: { untilContentDrained, receive in
                    try await connectivity.run(untilContentDrained: untilContentDrained, receive: receive)
                },
                requestContentDrain: {
                    connectivity.requestContentDrain($0)
                }
            )
        )
    }

    /// Owns reception for the view lifetime, including scene inactivity and background execution.
    func run() async {
        guard !Task.isCancelled else { return }
        while isRunning {
            await waitForConsumerRelease()
            guard !Task.isCancelled else { return }
        }
        await consume(untilContentDrained: false)
    }

    /// Joins a live receiver or runs one finite cold-launch lease until native pending content drains.
    func handleBackground() async {
        guard !Task.isCancelled else { return }
        while isRunning {
            if await waitForContentDrain() {
                return
            }
            guard !Task.isCancelled else { return }
        }
        await consume(untilContentDrained: true)
    }

    /// Reconciles foreground reentry through the same serial consumer without replacing its task.
    func reconcileLatestContext() async {
        await handleBackground()
    }

    private func consume(untilContentDrained: Bool) async {
        isRunning = true
        defer {
            isRunning = false
            finishDrainWaiters()
            for continuation in releaseWaiters.values {
                continuation.finish()
            }
            releaseWaiters.removeAll()
        }
        do {
            try await connection.run(untilContentDrained) { event in
                await self.receive(event)
            }
        } catch is CancellationError {
            return
        } catch {
            isTemporarilyUnavailable = true
        }
    }

    private func receive(_ event: WatchReadingConnectivity.Event) async {
        switch event {
        case .activated:
            isTemporarilyUnavailable = false
        case .received(let data):
            hasReceivedContext = true
            apply(await receiver.receive(data))
            isTemporarilyUnavailable = false
        case .invalidContext:
            hasReceivedContext = true
            apply(await receiver.receive(Data()))
            isTemporarilyUnavailable = false
        case .unavailable:
            if !hasReceivedContext {
                apply(await receiver.restore())
            }
            isTemporarilyUnavailable = true
            finishDrainWaiters(completed: true)
        case .contentDrained:
            if !hasReceivedContext {
                apply(await receiver.restore())
            }
        case .requestedContentDrained(let identity):
            if !hasReceivedContext {
                apply(await receiver.restore())
            }
            if let continuation = drainWaiters.removeValue(forKey: identity) {
                continuation.yield(true)
                continuation.finish()
            }
        }
    }

    private func apply(_ state: WatchReadingSnapshotState) {
        switch state {
        case .unavailable: snapshot = nil
        case .snapshot(let value): snapshot = value
        }
    }

    private func waitForContentDrain() async -> Bool {
        let identity = UUID()
        let signal = AsyncStream<Bool>.makeStream(bufferingPolicy: .bufferingNewest(1))
        drainWaiters[identity] = signal.continuation
        defer {
            drainWaiters.removeValue(forKey: identity)
            signal.continuation.finish()
        }
        connection.requestContentDrain(identity)
        for await completed in signal.stream {
            return completed
        }
        return false
    }

    private func waitForConsumerRelease() async {
        let identity = UUID()
        let signal = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        releaseWaiters[identity] = signal.continuation
        defer {
            releaseWaiters.removeValue(forKey: identity)
            signal.continuation.finish()
        }
        for await _ in signal.stream {
            return
        }
    }

    private func finishDrainWaiters(completed: Bool = false) {
        for continuation in drainWaiters.values {
            if completed {
                continuation.yield(true)
            }
            continuation.finish()
        }
        drainWaiters.removeAll()
    }
}
#endif
