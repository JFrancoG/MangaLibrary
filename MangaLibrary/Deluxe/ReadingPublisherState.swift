import Foundation

/// Private recovery metadata, never an authentication authority or a consumer payload.
struct ReadingPublisherState: Codable {
    let formatVersion: Int
    let publicationGeneration: UUID
    var lastReservedRevision: UInt64
    var lastReservedFenceRevision: UInt64
    var requiresRetirement: Bool
    var intent: Intent?

    enum Intent: Codable {
        case bootstrap(SessionFence)
        case publication(Publication)
        indirect case retirement(Retirement)
    }

    struct Publication: Codable {
        let revision: UInt64
        let sessionGeneration: UUID
        let snapshotDigest: Data
        let openingFence: SessionFence?
        let isRedacted: Bool
    }

    struct Retirement: Codable {
        let sessionGeneration: UUID
        let redactionSessionGeneration: UUID
        let fence: SessionFence
        let redactionRevision: UInt64
        var previousState: ReadingPublisherState?
        var previousFence: SessionFence?
    }

    func validate(allowingPreviousState: Bool = true) throws {
        guard formatVersion == 1, lastReservedFenceRevision > 0 else { throw ReadingPublicationError.incompatibleState }
        switch intent {
        case let .bootstrap(fence):
            guard valid(fence), fence.allowedSessionGeneration == nil else {
                throw ReadingPublicationError.incompatibleState
            }
        case let .publication(publication):
            guard
                publication.revision > 0,
                publication.revision <= lastReservedRevision,
                publication.snapshotDigest.count == 32
            else { throw ReadingPublicationError.incompatibleState }
            if let fence = publication.openingFence {
                let permitted = publication.isRedacted
                    ? fence.allowedSessionGeneration == nil
                    : fence.allowedSessionGeneration == publication.sessionGeneration
                guard valid(fence), permitted else { throw ReadingPublicationError.incompatibleState }
            }
        case let .retirement(retirement):
            guard
                valid(retirement.fence),
                retirement.fence.allowedSessionGeneration == nil,
                retirement.redactionRevision > 0,
                retirement.redactionRevision <= lastReservedRevision
            else { throw ReadingPublicationError.incompatibleState }
            if let previous = retirement.previousState, let fence = retirement.previousFence {
                guard
                    allowingPreviousState,
                    previous.publicationGeneration == fence.publicationGeneration,
                    fence.fenceRevision <= previous.lastReservedFenceRevision
                else { throw ReadingPublicationError.incompatibleState }
                try previous.validate(allowingPreviousState: false)
            } else if retirement.previousState != nil || retirement.previousFence != nil {
                throw ReadingPublicationError.incompatibleState
            }
        case nil:
            break
        }
    }

    func withoutRetirementPredecessor() -> Self {
        var copy = self
        if case var .retirement(retirement) = copy.intent {
            retirement.previousState = nil
            retirement.previousFence = nil
            copy.intent = .retirement(retirement)
        }
        return copy
    }

    private func valid(_ fence: SessionFence) -> Bool {
        fence.publicationGeneration == publicationGeneration
            && fence.fenceRevision <= lastReservedFenceRevision
    }
}
