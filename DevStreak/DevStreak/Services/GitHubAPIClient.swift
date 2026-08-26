//
//  GitHubAPIClient.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

nonisolated struct GitHubRateLimitDiagnostics: Equatable {
    let limit: Int?
    let remaining: Int?
    let resetAt: Date?

    init(limit: Int?, remaining: Int?, resetAt: Date?) {
        self.limit = limit
        self.remaining = remaining
        self.resetAt = resetAt
    }

    init(response: HTTPURLResponse) {
        limit = response.integerHeader("X-RateLimit-Limit")
        remaining = response.integerHeader("X-RateLimit-Remaining")

        if let resetTimestamp = response.integerHeader("X-RateLimit-Reset") {
            resetAt = Date(timeIntervalSince1970: TimeInterval(resetTimestamp))
        } else {
            resetAt = nil
        }
    }
}

nonisolated enum GitHubAPIError: Error, Equatable {
    case rateLimited(GitHubRateLimitDiagnostics?)
    case credentialUnavailable
    case unauthorized
    case forbidden
    case unauthorizedOrForbidden
    case notFound
    case networkFailure
    case decodingFailure
    case unexpectedStatus(Int)
}

nonisolated struct GitHubCommitSummary: Equatable {
    let sha: String
    let timestamp: Date
}

nonisolated struct GitHubPullRequest: Equatable {
    let number: Int
}

nonisolated struct GitHubCommitDetail: Equatable {
    let sha: String
    let filenames: [String]
}

nonisolated struct GitHubRepositorySummary: Equatable {
    let fullName: String
    let defaultBranch: String
    let isPrivate: Bool
    let createdAt: Date?
}

nonisolated struct GitHubPage<Value: Equatable>: Equatable {
    let values: [Value]
    let hasNextPage: Bool
}

nonisolated protocol GitHubAPIClientProtocol {
    func repository(owner: String, repository: String) async throws -> GitHubRepositorySummary
    func commits(owner: String, repository: String, ref: String, since: Date?, perPage: Int, page: Int) async throws -> GitHubPage<GitHubCommitSummary>
    func openPullRequests(owner: String, repository: String, perPage: Int, page: Int) async throws -> GitHubPage<GitHubPullRequest>
    func pullRequestCommits(owner: String, repository: String, number: Int, perPage: Int, page: Int) async throws -> GitHubPage<GitHubCommitSummary>
    func commitDetail(owner: String, repository: String, sha: String) async throws -> GitHubCommitDetail
}

nonisolated struct GitHubAPIClient: GitHubAPIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let authorizationHeaderProvider: (() throws -> String?)?
    private let dateFormatter: ISO8601DateFormatter

    init(
        baseURL: URL = URL(string: "https://api.github.com")!,
        session: URLSession = .shared,
        authorizationHeaderProvider: (() throws -> String?)? = GitHubCredentialStore().authorizationHeader
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authorizationHeaderProvider = authorizationHeaderProvider
        self.dateFormatter = ISO8601DateFormatter()
    }

    func repository(owner: String, repository: String) async throws -> GitHubRepositorySummary {
        let request = try request(path: "/repos/\(owner)/\(repository)", queryItems: [])
        let dto: GitHubRepositoryDTO = try await loadObject(request)
        return GitHubRepositorySummary(
            fullName: dto.fullName,
            defaultBranch: dto.defaultBranch,
            isPrivate: dto.isPrivate,
            createdAt: dto.createdAt.flatMap { dateFormatter.date(from: $0) }
        )
    }

    func commits(owner: String, repository: String, ref: String, since: Date?, perPage: Int, page: Int) async throws -> GitHubPage<GitHubCommitSummary> {
        var queryItems = [
            URLQueryItem(name: "sha", value: ref),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        if let since {
            queryItems.append(URLQueryItem(name: "since", value: dateFormatter.string(from: since)))
        }

        let request = try request(path: "/repos/\(owner)/\(repository)/commits", queryItems: queryItems)
        let page: GitHubPage<GitHubCommitSummaryDTO> = try await loadPage(request)
        return GitHubPage(
            values: try page.values.map { try $0.domainValue(formatter: dateFormatter) },
            hasNextPage: page.hasNextPage
        )
    }

    func openPullRequests(owner: String, repository: String, perPage: Int, page: Int) async throws -> GitHubPage<GitHubPullRequest> {
        let request = try request(path: "/repos/\(owner)/\(repository)/pulls", queryItems: [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ])
        let page: GitHubPage<GitHubPullRequestDTO> = try await loadPage(request)
        return GitHubPage(values: page.values.map { GitHubPullRequest(number: $0.number) }, hasNextPage: page.hasNextPage)
    }

    func pullRequestCommits(owner: String, repository: String, number: Int, perPage: Int, page: Int) async throws -> GitHubPage<GitHubCommitSummary> {
        let request = try request(path: "/repos/\(owner)/\(repository)/pulls/\(number)/commits", queryItems: [
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ])
        let page: GitHubPage<GitHubCommitSummaryDTO> = try await loadPage(request)
        return GitHubPage(
            values: try page.values.map { try $0.domainValue(formatter: dateFormatter) },
            hasNextPage: page.hasNextPage
        )
    }

    func commitDetail(owner: String, repository: String, sha: String) async throws -> GitHubCommitDetail {
        let request = try request(path: "/repos/\(owner)/\(repository)/commits/\(sha)", queryItems: [])
        let dto: GitHubCommitDetailDTO = try await loadObject(request)
        return GitHubCommitDetail(sha: dto.sha, filenames: dto.files.map(\.filename))
    }

    private func request(path: String, queryItems: [URLQueryItem]) throws -> URLRequest {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(url: baseURL.appendingPathComponent(normalizedPath), resolvingAgainstBaseURL: false) else {
            throw GitHubAPIError.networkFailure
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw GitHubAPIError.networkFailure
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let authorizationHeader: String?
        do {
            authorizationHeader = try authorizationHeaderProvider?()
        } catch {
            throw GitHubAPIError.credentialUnavailable
        }

        if let authorizationHeader, !authorizationHeader.isEmpty {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func loadObject<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubAPIError.networkFailure
        }

        try validate(response: response)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GitHubAPIError.decodingFailure
        }
    }

    private func loadPage<T: Decodable & Equatable>(_ request: URLRequest) async throws -> GitHubPage<T> {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubAPIError.networkFailure
        }

        let httpResponse = try validate(response: response)

        do {
            let decoded = try JSONDecoder().decode([T].self, from: data)
            return GitHubPage(values: decoded, hasNextPage: hasNextPage(httpResponse))
        } catch {
            throw GitHubAPIError.decodingFailure
        }
    }

    @discardableResult
    private func validate(response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.networkFailure
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return httpResponse
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            if httpResponse.isRateLimited {
                throw GitHubAPIError.rateLimited(GitHubRateLimitDiagnostics(response: httpResponse))
            }
            throw GitHubAPIError.forbidden
        case 429:
            throw GitHubAPIError.rateLimited(GitHubRateLimitDiagnostics(response: httpResponse))
        case 404:
            throw GitHubAPIError.notFound
        default:
            throw GitHubAPIError.unexpectedStatus(httpResponse.statusCode)
        }
    }

    private func hasNextPage(_ response: HTTPURLResponse) -> Bool {
        response.value(forHTTPHeaderField: "Link")?.contains("rel=\"next\"") == true
    }
}

private nonisolated extension HTTPURLResponse {
    var isRateLimited: Bool {
        value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0"
        || value(forHTTPHeaderField: "Retry-After") != nil
    }

    func integerHeader(_ name: String) -> Int? {
        guard let value = value(forHTTPHeaderField: name) else {
            return nil
        }

        return Int(value)
    }
}

private nonisolated struct GitHubCommitSummaryDTO: Decodable, Equatable {
    let sha: String
    let commit: CommitDTO

    func domainValue(formatter: ISO8601DateFormatter) throws -> GitHubCommitSummary {
        let timestampString = commit.author?.date ?? commit.committer?.date
        guard let timestampString,
              let timestamp = formatter.date(from: timestampString) else {
            throw GitHubAPIError.decodingFailure
        }

        return GitHubCommitSummary(sha: sha, timestamp: timestamp)
    }

    nonisolated struct CommitDTO: Decodable, Equatable {
        let author: TimestampDTO?
        let committer: TimestampDTO?
    }

    nonisolated struct TimestampDTO: Decodable, Equatable {
        let date: String
    }
}

private nonisolated struct GitHubPullRequestDTO: Decodable, Equatable {
    let number: Int
}

private nonisolated struct GitHubRepositoryDTO: Decodable {
    let fullName: String
    let defaultBranch: String
    let isPrivate: Bool
    let createdAt: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case defaultBranch = "default_branch"
        case isPrivate = "private"
        case createdAt = "created_at"
    }
}

private nonisolated struct GitHubCommitDetailDTO: Decodable {
    let sha: String
    let files: [FileDTO]

    nonisolated struct FileDTO: Decodable {
        let filename: String
    }
}
