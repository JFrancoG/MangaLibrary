//
//  UserRegistrationClientTests.swift
//  MangaLibraryTests
//

import Foundation
import Testing
@testable import MangaLibrary

@Suite("User registration client", .tags(.fast))
struct UserRegistrationClientTests {
    @Test("Registration sends the exact live contract and accepts its opaque integer")
    func registrationUsesTheLiveContract() async throws(any Error) {
        let recorder = RegistrationRecordedDataLoader(data: Data("42".utf8))
        let register = try makeOperation { request in
            await recorder.load(request)
        }

        let submission = await register(
            "reader@example.invalid",
            "synthetic-passphrase"
        )

        #expect(submission == .confirmed)
        let requests = await recorder.requests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://registration.example.test/users")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "App-Token") == "synthetic-app-token")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

        let body = try #require(request.httpBody)
        let submittedUser = try JSONDecoder().decode([String: String].self, from: body)
        #expect(
            submittedUser == [
                "email": "reader@example.invalid",
                "password": "synthetic-passphrase"
            ]
        )
    }

    @Test(
        "Missing registration configuration fails before transport",
        arguments: InvalidRegistrationAppToken.allCases
    )
    fileprivate func invalidConfigurationFailsClosed(
        _ invalidToken: InvalidRegistrationAppToken
    ) async throws(any Error) {
        let recorder = RegistrationRecordedDataLoader(data: Data("42".utf8))
        let register = try makeOperation(
            appToken: invalidToken.value,
            loadData: { request in
                await recorder.load(request)
            }
        )

        let submission = await register(
            "reader@example.invalid",
            "synthetic-passphrase"
        )

        #expect(submission == .notSubmitted(.configurationUnavailable))
        #expect(await recorder.requests().isEmpty)
    }

    @Test("An explicit HTTP rejection leaves the remote outcome unconfirmed")
    func explicitHTTPRejectionIsUnconfirmed() async throws(any Error) {
        let register = try makeOperation { _ in
            throw NetworkError.statusCode(409)
        }

        let submission = await register(
            "reader@example.invalid",
            "synthetic-passphrase"
        )

        #expect(submission == .unconfirmed(.network(.statusCode(409))))
    }

    @Test("A timeout after submission leaves the remote outcome unconfirmed")
    func timeoutIsUnconfirmed() async throws(any Error) {
        let register = try makeOperation { _ in
            throw NetworkError.transport(.timedOut)
        }

        let submission = await register(
            "reader@example.invalid",
            "synthetic-passphrase"
        )

        #expect(submission == .unconfirmed(.network(.transport(.timedOut))))
    }

    @Test("A confirmed status with an invalid payload leaves the outcome unconfirmed")
    func invalidConfirmationPayloadIsUnconfirmed() async throws(any Error) {
        let register = try makeOperation(returning: Data(#"{"id":42}"#.utf8))

        let submission = await register(
            "reader@example.invalid",
            "synthetic-passphrase"
        )

        #expect(submission == .unconfirmed(.contractDrift))
    }

    @Test("Cancellation after submission leaves the remote outcome unconfirmed")
    func cancellationAfterSubmissionIsUnconfirmed() async throws(any Error) {
        let register = try makeOperation { _ in
            throw CancellationError()
        }

        let submission = await register(
            "reader@example.invalid",
            "synthetic-passphrase"
        )

        #expect(submission == .unconfirmed(.cancelled))
    }

    @Test("Cancellation before submission never reaches transport")
    func cancellationBeforeSubmissionIsNotSubmitted() async throws(any Error) {
        let recorder = RegistrationRecordedDataLoader(data: Data("42".utf8))
        let gate = RegistrationOperationGate()
        let register = try makeOperation { request in
            await recorder.load(request)
        }

        let submissionTask = Task {
            await gate.suspendUntilOpen()
            return await register(
                "reader@example.invalid",
                "synthetic-passphrase"
            )
        }
        await gate.waitUntilArrived()
        submissionTask.cancel()
        await gate.open()

        let submission = await submissionTask.value

        #expect(submission == .notSubmitted(.cancelled))
        #expect(await recorder.requests().isEmpty)
    }

    @Test("An unclassified loader failure leaves the remote outcome unconfirmed")
    func unclassifiedFailureIsUnconfirmed() async throws(any Error) {
        let register = try makeOperation { _ in
            throw RegistrationLoaderFailure()
        }

        let submission = await register(
            "reader@example.invalid",
            "synthetic-passphrase"
        )

        #expect(submission == .unconfirmed(.unavailable))
    }

    fileprivate func makeOperation(
        appToken: String? = "synthetic-app-token",
        returning data: Data
    ) throws(any Error) -> UserRegistrationClient.Operation {
        try makeOperation(appToken: appToken) { _ in data }
    }

    fileprivate func makeOperation(
        appToken: String? = "synthetic-app-token",
        loadData: @escaping UserRegistrationClient.DataLoader
    ) throws(any Error) -> UserRegistrationClient.Operation {
        let baseURL = try #require(URL(string: "https://registration.example.test"))

        return UserRegistrationClient.operation(
            configuration: try APIConfiguration(baseURL: baseURL),
            appToken: appToken,
            loadData: loadData
        )
    }
}

private enum InvalidRegistrationAppToken: CaseIterable, CustomTestStringConvertible {
    case missing
    case empty
    case whitespace
    case unresolvedBuildSetting

    var value: String? {
        switch self {
        case .missing:
            nil
        case .empty:
            ""
        case .whitespace:
            "  \n"
        case .unresolvedBuildSetting:
            "$(MANGA_LIBRARY_APP_TOKEN)"
        }
    }

    var testDescription: String {
        switch self {
        case .missing: "missing"
        case .empty: "empty"
        case .whitespace: "whitespace"
        case .unresolvedBuildSetting: "unresolved build setting"
        }
    }
}

private struct RegistrationLoaderFailure: Error {}

private actor RegistrationRecordedDataLoader {
    private let data: Data
    private var recordedRequests: [URLRequest] = []

    init(data: Data) {
        self.data = data
    }

    func load(_ request: URLRequest) -> Data {
        recordedRequests.append(request)
        return data
    }

    func requests() -> [URLRequest] {
        recordedRequests
    }
}

private actor RegistrationOperationGate {
    private var didArrive = false
    private var isOpen = false
    private var arrivalContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitUntilArrived() async {
        guard didArrive == false else { return }

        await withCheckedContinuation {
            arrivalContinuation = $0
        }
    }

    func suspendUntilOpen() async {
        didArrive = true
        arrivalContinuation?.resume()
        arrivalContinuation = nil
        guard isOpen == false else { return }

        await withCheckedContinuation {
            releaseContinuation = $0
        }
    }

    func open() {
        isOpen = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
