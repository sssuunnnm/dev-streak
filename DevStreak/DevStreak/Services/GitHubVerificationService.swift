//
//  GitHubVerificationService.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

enum GitHubVerificationFailure: Error, Equatable {
    case rateLimited
    case unauthorizedOrForbidden
    case notFound
    case networkFailure
    case decodingFailure
    case unknown
}

struct GitHubVerificationResult: Equatable {
    let verifiedDateKeys: Set<String>

    var hasActivity: Bool {
        !verifiedDateKeys.isEmpty
    }
}

struct GitHubVerificationService {
    private let client: GitHubAPIClientProtocol
    private let dateService: DateService
    private let pathMatcher: GitHubContentPathMatcher
    private let owner: String
    private let repository: String
    private let mainRef: String
    private let lookbackDays: Int
    private let commitListLimit: Int
    private let pullRequestLimit: Int

    init(
        client: GitHubAPIClientProtocol = GitHubAPIClient(),
        dateService: DateService = DateService(),
        pathMatcher: GitHubContentPathMatcher = GitHubContentPathMatcher(),
        owner: String = "sssuunnnm",
        repository: String = "dev-archive",
        mainRef: String = "main",
        lookbackDays: Int = 3,
        commitListLimit: Int = 30,
        pullRequestLimit: Int = 20
    ) {
        self.client = client
        self.dateService = dateService
        self.pathMatcher = pathMatcher
        self.owner = owner
        self.repository = repository
        self.mainRef = mainRef
        self.lookbackDays = lookbackDays
        self.commitListLimit = commitListLimit
        self.pullRequestLimit = pullRequestLimit
    }

    func verify(now: Date = .now) async -> Result<GitHubVerificationResult, GitHubVerificationFailure> {
        do {
            let result = try await verifiedActivity(now: now)
            return .success(result)
        } catch let error as GitHubAPIError {
            return .failure(Self.failure(from: error))
        } catch {
            return .failure(.unknown)
        }
    }

    func verifiedActivity(now: Date = .now) async throws -> GitHubVerificationResult {
        let since = verificationStartDate(now: now)
        var candidates: [GitHubCommitSummary] = []

        candidates += try await client.commits(
            owner: owner,
            repository: repository,
            ref: mainRef,
            since: since,
            perPage: commitListLimit
        )

        let pullRequests = try await client.openPullRequests(
            owner: owner,
            repository: repository,
            perPage: pullRequestLimit
        )

        for pullRequest in pullRequests {
            candidates += try await client.pullRequestCommits(
                owner: owner,
                repository: repository,
                number: pullRequest.number,
                perPage: commitListLimit
            )
        }

        let dedupedCandidates = deduplicated(candidates)
            .filter { $0.timestamp >= since }

        var verifiedDateKeys = Set<String>()

        for candidate in dedupedCandidates {
            let detail = try await client.commitDetail(
                owner: owner,
                repository: repository,
                sha: candidate.sha
            )

            guard pathMatcher.containsWritingContentPath(detail.filenames) else {
                continue
            }

            verifiedDateKeys.insert(dateService.dateKey(for: candidate.timestamp))
        }

        return GitHubVerificationResult(verifiedDateKeys: verifiedDateKeys)
    }

    func deduplicated(_ commits: [GitHubCommitSummary]) -> [GitHubCommitSummary] {
        var seenSHAs = Set<String>()
        var result: [GitHubCommitSummary] = []

        for commit in commits where !seenSHAs.contains(commit.sha) {
            seenSHAs.insert(commit.sha)
            result.append(commit)
        }

        return result
    }

    private func verificationStartDate(now: Date) -> Date {
        let todayKey = dateService.todayKey(now: now)
        guard let startKey = dateService.addingDays(-lookbackDays, to: todayKey),
              let startDate = dateService.date(from: startKey) else {
            return now
        }

        return startDate
    }

    private static func failure(from error: GitHubAPIError) -> GitHubVerificationFailure {
        switch error {
        case .rateLimited:
            return .rateLimited
        case .unauthorizedOrForbidden:
            return .unauthorizedOrForbidden
        case .notFound:
            return .notFound
        case .networkFailure:
            return .networkFailure
        case .decodingFailure:
            return .decodingFailure
        case .unexpectedStatus:
            return .unknown
        }
    }
}
