//
//  GitHubAPIClientTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

@Suite(.serialized)
struct GitHubAPIClientTests {
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
        authorizationHeaderProvider: @escaping () -> String?,
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
}

private final class LockedHeaders: @unchecked Sendable {
    private let lock = NSLock()
    private var headers: [String: String] = [:]

    func capture(_ request: URLRequest) {
        lock.withLock {
            headers = request.allHTTPHeaderFields ?? [:]
        }
    }

    func value(for field: String) -> String? {
        lock.withLock {
            headers[field]
        }
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
