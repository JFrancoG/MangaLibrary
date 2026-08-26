//
//  CatalogPreviewSupport.swift
//  MangaLibrary
//

import Foundation

enum CatalogFixtureScenario: String {
    static let launchArgument = "-catalog-fixture"

    case content
    case empty
    case error

    init?(arguments: [String]) {
        guard let rawValue = arguments
            .drop(while: { $0 != Self.launchArgument })
            .dropFirst()
            .first
        else {
            return nil
        }

        self.init(rawValue: rawValue)
    }
}

enum CatalogPreviewSupport {
    static let mangas = [
        Manga(
            id: 1,
            title: "Fullmetal Alchemist",
            titleEnglish: "Fullmetal Alchemist",
            titleJapanese: "鋼の錬金術師",
            synopsis: "Two brothers search for the Philosopher's Stone after an alchemical ritual changes their lives.",
            score: 9.12,
            coverURL: nil
        ),
        Manga(
            id: 2,
            title: "A deliberately long manga title that exercises multiline layout",
            titleEnglish: nil,
            titleJapanese: nil,
            synopsis: nil,
            score: 8.4,
            coverURL: nil
        ),
        Manga(
            id: 3,
            title: "Monster",
            titleEnglish: nil,
            titleJapanese: "MONSTER",
            synopsis: "A doctor confronts the consequences of saving one life.",
            score: 9.15,
            coverURL: nil
        ),
        Manga(
            id: 4,
            title: "Nausicaä of the Valley of the Wind",
            titleEnglish: "Nausicaä of the Valley of the Wind",
            titleJapanese: "風の谷のナウシカ",
            synopsis: nil,
            score: 8.85,
            coverURL: nil
        )
    ]

    static var catalogClient: CatalogAPIClient {
        get {
            do {
                return try catalogClient(for: .content)
            } catch {
                preconditionFailure("The deterministic catalog fixture is invalid.")
            }
        }
    }

    static func catalogClient(for scenario: CatalogFixtureScenario) throws -> CatalogAPIClient {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [CatalogFixtureURLProtocol.self]
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: sessionConfiguration)
        let baseURL = requiredURL("https://\(scenario.rawValue).catalog.fixture")

        return CatalogAPIClient(
            httpClient: HTTPClient(session: session),
            configuration: try APIConfiguration(baseURL: baseURL)
        )
    }

    @MainActor
    static func model(state: CatalogModel.State) -> CatalogModel {
        let client = catalogClient

        return CatalogModel(initialState: state) { request in
            try await client.fetch(request)
        }
    }

    private static func requiredURL(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("The deterministic fixture URL is invalid.")
        }

        return url
    }
}

private final class CatalogFixtureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host()?.hasSuffix(".catalog.fixture") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let requestIsValid = request.httpMethod == "GET"
            && url.path() == "/list/mangas"
            && url.query() == "page=1&per=20"
            && request.value(forHTTPHeaderField: "Authorization") == nil
            && request.value(forHTTPHeaderField: "App-Token") == nil

        guard requestIsValid else {
            send(statusCode: 400, body: Data(), url: url)
            return
        }

        switch url.host() {
        case "content.catalog.fixture":
            send(statusCode: 200, body: Self.contentFixture, url: url)
        case "empty.catalog.fixture":
            send(statusCode: 200, body: Self.emptyFixture, url: url)
        case "error.catalog.fixture":
            send(statusCode: 503, body: Data(), url: url)
        default:
            send(statusCode: 404, body: Data(), url: url)
        }
    }

    override func stopLoading() {}

    private func send(statusCode: Int, body: Data, url: URL) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static let emptyFixture = Data(
        #"{"items":[],"metadata":{"page":1,"per":20,"total":0}}"#.utf8
    )

    private static let contentFixture = Data(
        #"{"items":[{"authors":[{"firstName":"Hiromu","id":"19bcb3f8-f755-4dc9-b55b-fc86d206af1f","lastName":"Arakawa","role":"Story & Art"}],"background":null,"chapters":116,"demographics":[{"demographic":"Shounen","id":"8f237731-f5de-4ca4-9ad8-721f0285026e"}],"endDate":"2010-07-12T00:00:00Z","genres":[{"genre":"Adventure","id":"fb743fc5-288c-473a-89ee-73bc4c8a1e53"}],"id":1,"mainPicture":null,"score":9.12,"startDate":"2001-07-12T00:00:00Z","status":"finished","sypnosis":"Two brothers search for the Philosopher's Stone.","themes":[{"id":"3eca0fd4-c771-4e5e-bd7d-71f61ae2f47c","theme":"Military"}],"title":"Fullmetal Alchemist","titleEnglish":"Fullmetal Alchemist","titleJapanese":"鋼の錬金術師","url":"https://example.test/manga/1","volumes":27}],"metadata":{"page":1,"per":20,"total":1}}"#.utf8
    )
}
