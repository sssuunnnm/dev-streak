//
//  GitHubAPIClientTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Security
import Testing
@testable import DevStreak

@Suite(.serialized)
struct GitHubAPIClientTests {
    @Test func repositoryEndpointHTTP200ReturnsConnectionSuccess() async throws {
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(
                statusCode: 200,
                headers: [:],
                body: #"{"full_name":"sssuunnnm/dev-archive","default_branch":"main","private":false}"#
            ),
            capturedHeaders: LockedHeaders()
        )
        let service = GitHubConnectionTestService(client: client)

        let result = await service.testConnection()

        #expect(try result.get().fullName == "sssuunnnm/dev-archive")
    }

    @Test func repositoryResponseUsesMinimalDecoding() async throws {
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(
                statusCode: 200,
                headers: [:],
                body: #"{"id":123,"name":"dev-archive","full_name":"sssuunnnm/dev-archive","default_branch":"main","private":false,"unused":{"nested":true}}"#
            ),
            capturedHeaders: LockedHeaders()
        )

        let repository = try await client.repository(owner: "sssuunnnm", repository: "dev-archive")

        #expect(repository.fullName == "sssuunnnm/dev-archive")
        #expect(repository.defaultBranch == "main")
        #expect(!repository.isPrivate)
    }

    @Test func savedTokenAddsAuthorizationHeaderToRepositoryConnectionTest() async throws {
        let tokenStore = InMemoryGitHubTokenStore()
        let credentialStore = GitHubCredentialStore(tokenStore: tokenStore)
        try credentialStore.saveToken("  github_pat_secret  \n")

        let capturedHeaders = LockedHeaders()
        let client = Self.client(
            authorizationHeaderProvider: credentialStore.authorizationHeader,
            response: .success(
                statusCode: 200,
                headers: [:],
                body: #"{"full_name":"sssuunnnm/dev-archive","default_branch":"main","private":false}"#
            ),
            capturedHeaders: capturedHeaders
        )

        _ = try await client.repository(owner: "sssuunnnm", repository: "dev-archive")

        #expect(capturedHeaders.value(for: "Authorization") == "Bearer github_pat_secret")
        #expect(capturedHeaders.path == "/repos/sssuunnnm/dev-archive")
    }

    @Test func deletedTokenOmitsAuthorizationHeaderFromRepositoryConnectionTest() async throws {
        let tokenStore = InMemoryGitHubTokenStore()
        let credentialStore = GitHubCredentialStore(tokenStore: tokenStore)
        try credentialStore.saveToken("github_pat_secret")
        try credentialStore.deleteToken()

        let capturedHeaders = LockedHeaders()
        let client = Self.client(
            authorizationHeaderProvider: credentialStore.authorizationHeader,
            response: .success(
                statusCode: 200,
                headers: [:],
                body: #"{"full_name":"sssuunnnm/dev-archive","default_branch":"main","private":false}"#
            ),
            capturedHeaders: capturedHeaders
        )

        _ = try await client.repository(owner: "sssuunnnm", repository: "dev-archive")

        #expect(capturedHeaders.value(for: "Authorization") == nil)
    }

    @Test func repositoryConnectionErrorMappingIsSpecific() async throws {
        await Self.expectConnectionFailure(statusCode: 401, headers: [:], expected: .invalidToken)
        await Self.expectConnectionFailure(statusCode: 403, headers: [:], expected: .forbidden)
        await Self.expectConnectionFailure(statusCode: 404, headers: [:], expected: .repositoryNotFound)
        await Self.expectConnectionFailure(
            statusCode: 403,
            headers: [
                "X-RateLimit-Limit": "5000",
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": "1787381200"
            ],
            expected: .rateLimited(GitHubRateLimitDiagnostics(
                limit: 5000,
                remaining: 0,
                resetAt: Date(timeIntervalSince1970: 1_787_381_200)
            ))
        )
    }

    @Test func validRepositoryResponseIsNotTreatedAsDecodingFailure() async throws {
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(
                statusCode: 200,
                headers: [:],
                body: #"{"full_name":"sssuunnnm/dev-archive","default_branch":"main","private":false}"#
            ),
            capturedHeaders: LockedHeaders()
        )
        let service = GitHubConnectionTestService(client: client)

        if case .failure(.decodingFailure) = await service.testConnection() {
            Issue.record("Valid repository metadata should not fail decoding.")
        }
    }

    @Test func tokenAddsAuthorizationHeader() async throws {
        let capturedHeaders = LockedHeaders()
        let client = Self.client(
            authorizationHeaderProvider: {
                "Bearer github_pat_secret"
            },
            response: .success(statusCode: 200, headers: [:], body: "[]"),
            capturedHeaders: capturedHeaders
        )

        _ = try await client.openPullRequests(owner: "sssuunnnm", repository: "dev-archive", perPage: 20, page: 1)

        #expect(capturedHeaders.value(for: "Authorization") == "Bearer github_pat_secret")
    }

    @Test func missingTokenDoesNotAddAuthorizationHeader() async throws {
        let capturedHeaders = LockedHeaders()
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(statusCode: 200, headers: [:], body: "[]"),
            capturedHeaders: capturedHeaders
        )

        _ = try await client.openPullRequests(owner: "sssuunnnm", repository: "dev-archive", perPage: 20, page: 1)

        #expect(capturedHeaders.value(for: "Authorization") == nil)
    }

    @Test func rateLimitHeadersAreParsed() async throws {
        let resetAt = 1_787_381_200
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(
                statusCode: 403,
                headers: [
                    "X-RateLimit-Limit": "60",
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": "\(resetAt)"
                ],
                body: "{}"
            ),
            capturedHeaders: LockedHeaders()
        )

        do {
            _ = try await client.openPullRequests(owner: "sssuunnnm", repository: "dev-archive", perPage: 20, page: 1)
            Issue.record("Expected rate limit failure.")
        } catch GitHubAPIError.rateLimited(let diagnostics) {
            #expect(diagnostics?.limit == 60)
            #expect(diagnostics?.remaining == 0)
            #expect(diagnostics?.resetAt == Date(timeIntervalSince1970: TimeInterval(resetAt)))
        }
    }

    @Test func secondaryRateLimitRetryAfterOn403IsRateLimited() async throws {
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(
                statusCode: 403,
                headers: ["Retry-After": "60"],
                body: "{}"
            ),
            capturedHeaders: LockedHeaders()
        )

        do {
            _ = try await client.openPullRequests(owner: "sssuunnnm", repository: "dev-archive", perPage: 20, page: 1)
            Issue.record("Expected secondary rate limit failure.")
        } catch GitHubAPIError.rateLimited(_) {
        }
    }

    @Test func http429IsRateLimited() async throws {
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(statusCode: 429, headers: [:], body: "{}"),
            capturedHeaders: LockedHeaders()
        )

        do {
            _ = try await client.openPullRequests(owner: "sssuunnnm", repository: "dev-archive", perPage: 20, page: 1)
            Issue.record("Expected rate limit failure.")
        } catch GitHubAPIError.rateLimited(_) {
        }
    }

    @Test func regular403StaysForbidden() async throws {
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(statusCode: 403, headers: [:], body: "{}"),
            capturedHeaders: LockedHeaders()
        )

        do {
            _ = try await client.openPullRequests(owner: "sssuunnnm", repository: "dev-archive", perPage: 20, page: 1)
            Issue.record("Expected forbidden failure.")
        } catch GitHubAPIError.forbidden {
        }
    }

    @Test func credentialLoadFailureDoesNotFallBackToUnauthenticatedRequest() async throws {
        let tokenStore = InMemoryGitHubTokenStore(loadError: .keychainFailure(errSecInteractionNotAllowed))
        let credentialStore = GitHubCredentialStore(tokenStore: tokenStore)
        let capturedHeaders = LockedHeaders()
        let client = Self.client(
            authorizationHeaderProvider: credentialStore.authorizationHeader,
            response: .success(statusCode: 200, headers: [:], body: "[]"),
            capturedHeaders: capturedHeaders
        )

        do {
            _ = try await client.openPullRequests(owner: "sssuunnnm", repository: "dev-archive", perPage: 20, page: 1)
            Issue.record("Expected credential failure.")
        } catch GitHubAPIError.credentialUnavailable {
            #expect(capturedHeaders.path == nil)
        }
    }

    @Test func tokenIsNotIncludedInErrorDescription() async throws {
        let token = "github_pat_should_not_leak"
        let client = Self.client(
            authorizationHeaderProvider: {
                "Bearer \(token)"
            },
            response: .success(statusCode: 401, headers: [:], body: "{}"),
            capturedHeaders: LockedHeaders()
        )

        do {
            _ = try await client.openPullRequests(owner: "sssuunnnm", repository: "dev-archive", perPage: 20, page: 1)
            Issue.record("Expected authorization failure.")
        } catch {
            #expect(!String(describing: error).contains(token))
        }
    }

    private static func client(
        authorizationHeaderProvider: @escaping () throws -> String?,
        response: MockGitHubURLProtocol.Response,
        capturedHeaders: LockedHeaders
    ) -> GitHubAPIClient {
        MockGitHubURLProtocol.response = response
        MockGitHubURLProtocol.capturedHeaders = capturedHeaders

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockGitHubURLProtocol.self]

        return GitHubAPIClient(
            baseURL: URL(string: "https://api.github.test")!,
            session: URLSession(configuration: configuration),
            authorizationHeaderProvider: authorizationHeaderProvider
        )
    }

    private static func expectConnectionFailure(
        statusCode: Int,
        headers: [String: String],
        expected: GitHubConnectionFailure
    ) async {
        let client = Self.client(
            authorizationHeaderProvider: {
                nil
            },
            response: .success(statusCode: statusCode, headers: headers, body: "{}"),
            capturedHeaders: LockedHeaders()
        )
        let service = GitHubConnectionTestService(client: client)

        switch await service.testConnection() {
        case .success:
            Issue.record("Expected connection failure.")
        case .failure(let failure):
            #expect(failure == expected)
        }
    }
}

private final class LockedHeaders: @unchecked Sendable {
    private let lock = NSLock()
    private var headers: [String: String] = [:]
    private var requestURL: URL?

    func capture(_ request: URLRequest) {
        lock.withLock {
            headers = request.allHTTPHeaderFields ?? [:]
            requestURL = request.url
        }
    }

    func value(for field: String) -> String? {
        lock.withLock {
            headers[field]
        }
    }

    var path: String? {
        lock.withLock {
            requestURL?.path
        }
    }
}

private final class InMemoryGitHubTokenStore: GitHubTokenStoreProtocol {
    private var token: String?
    private let loadError: GitHubCredentialError?

    init(loadError: GitHubCredentialError? = nil) {
        self.loadError = loadError
    }

    func loadToken() throws -> String? {
        if let loadError {
            throw loadError
        }

        return token
    }

    func saveToken(_ token: String) throws {
        self.token = token
    }

    func deleteToken() throws {
        token = nil
    }
}

private final class MockGitHubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Response {
        case success(statusCode: Int, headers: [String: String], body: String)
    }

    nonisolated(unsafe) static var response: Response = .success(statusCode: 200, headers: [:], body: "[]")
    nonisolated(unsafe) static var capturedHeaders = LockedHeaders()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedHeaders.capture(request)

        switch Self.response {
        case .success(let statusCode, let headers, let body):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
