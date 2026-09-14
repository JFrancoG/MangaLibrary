import Foundation

extension CollectionMutationActor {
    /// Checks stored outbox structure without authorizing a user or validating volume policy.
    ///
    /// Confirmed cursors tolerate residual retry dates. Operations with stricter
    /// requirements validate that exception before applying their own effects.
    func hasValidOutboxStructure(_ operation: CollectionOutboxOperation) -> Bool {
        guard
            operation.mangaID > 0,
            operation.sequence > 0,
            operation.retryCount >= 0,
            operation.isTombstone == operation.desiredState.isTombstone
        else { return false }

        if operation.state == .retry {
            guard let nextRetryAt = operation.nextRetryAt else { return false }
            return nextRetryAt.timeIntervalSinceReferenceDate.isFinite
        }
        return operation.state == .confirmed || operation.nextRetryAt == nil
    }
}
