//
//  GitHubAPIClient.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

enum GitHubAPIError: Error, Equatable {
    case rateLimited
    case unauthorizedOrForbidden
    case notFound
    case networkFailure
    case decodingFailure
    case unexpectedStatus(Int)
}

struct GitHubCommitSummary: Equatable {
    let sha: String
    let timestamp: Date
}

struct GitHubPullRequest: Equatable {
    let number: Int
}

struct GitHubCommitDetail: Equatable {
    let sha: String
    let filenames: [String]
}

protocol GitHubAPIClientProtocol {
    func commits(owner: String, repository: String, ref: String, since: Date?, perPage: Int) async throws -> [GitHubCommitSummary]
    func openPullRequests(owner: String, repository: String, perPage: Int) async throws -> [GitHubPullRequest]
    func pullRequestCommits(owner: String, repository: String, number: Int, perPage: Int) async throws -> [GitHubCommitSummary]
    func commitDetail(owner: String, repository: String, sha: String) async throws -> GitHubCommitDetail
}

struct GitHubAPIClient: GitHubAPIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let authorizationHeaderProvider: (() -> String?)?
    private let dateFormatter: ISO8601DateFormatter

    init(
        baseURL: URL = URL(string: "https://api.github.com")!,
        session: URLSession = .shared,
        authorizationHeaderProvider: (() -> String?)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authorizationHeaderProvider = authorizationHeaderProvider
        self.dateFormatter = ISO8601DateFormatter()
    }

    func commits(owner: String, repository: String, ref: String, since: Date?, perPage: Int) async throws -> [GitHubCommitSummary] {
        var queryItems = [
            URLQueryItem(name: "sha", value: ref),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]

        if let since {
            queryItems.append(URLQueryItem(name: "since", value: dateFormatter.string(from: since)))
        }

        let request = try request(path: "/repos/\(owner)/\(repository)/commits", queryItems: queryItems)
        let dtos: [GitHubCommitSummaryDTO] = try await load(request)
        return try dtos.map { try $0.domainValue(formatter: dateFormatter) }
    }

    func openPullRequests(owner: String, repository: String, perPage: Int) async throws -> [GitHubPullRequest] {
        let request = try request(path: "/repos/\(owner)/\(repository)/pulls", queryItems: [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ])
        let dtos: [GitHubPullRequestDTO] = try await load(request)
        return dtos.map { GitHubPullRequest(number: $0.number) }
    }

    func pullRequestCommits(owner: String, repository: String, number: Int, perPage: Int) async throws -> [GitHubCommitSummary] {
        let request = try request(path: "/repos/\(owner)/\(repository)/pulls/\(number)/commits", queryItems: [
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ])
        let dtos: [GitHubCommitSummaryDTO] = try await load(request)
        return try dtos.map { try $0.domainValue(formatter: dateFormatter) }
    }

    func commitDetail(owner: String, repository: String, sha: String) async throws -> GitHubCommitDetail {
        let request = try request(path: "/repos/\(owner)/\(repository)/commits/\(sha)", queryItems: [])
        let dto: GitHubCommitDetailDTO = try await load(request)
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

        if let authorizationHeader = authorizationHeaderProvider?(), !authorizationHeader.isEmpty {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func load<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubAPIError.networkFailure
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.networkFailure
        }

        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw GitHubAPIError.decodingFailure
            }
        case 401, 403:
            if httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
                throw GitHubAPIError.rateLimited
            }
            throw GitHubAPIError.unauthorizedOrForbidden
        case 404:
            throw GitHubAPIError.notFound
        default:
            throw GitHubAPIError.unexpectedStatus(httpResponse.statusCode)
        }
    }
}

private struct GitHubCommitSummaryDTO: Decodable {
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

    struct CommitDTO: Decodable {
        let author: TimestampDTO?
        let committer: TimestampDTO?
    }

    struct TimestampDTO: Decodable {
        let date: String
    }
}

private struct GitHubPullRequestDTO: Decodable {
    let number: Int
}

private struct GitHubCommitDetailDTO: Decodable {
    let sha: String
    let files: [FileDTO]

    struct FileDTO: Decodable {
        let filename: String
    }
}
