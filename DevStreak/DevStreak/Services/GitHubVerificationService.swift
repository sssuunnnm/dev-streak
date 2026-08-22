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
    case budgetExceeded
    case unknown
}

struct GitHubVerificationResult: Equatable {
    let verifiedDateKeys: Set<String>

    var hasActivity: Bool {
        !verifiedDateKeys.isEmpty
    }
}

struct GitHubVerificationBudget {
    let maxRequestsPerVerification: Int
    private(set) var usedRequests = 0

    init(maxRequestsPerVerification: Int = 20) {
        self.maxRequestsPerVerification = maxRequestsPerVerification
    }

    mutating func consume() throws {
        guard usedRequests < maxRequestsPerVerification else {
            throw GitHubVerificationFailure.budgetExceeded
        }

        usedRequests += 1
    }
}

actor GitHubCommitDetailCache {
    private var contentPathBySHA: [String: Bool] = [:]

    func contentPathResult(for sha: String) -> Bool? {
        contentPathBySHA[sha]
    }

    func store(_ value: Bool, for sha: String) {
        contentPathBySHA[sha] = value
    }
}

struct GitHubVerificationService {
    private let client: GitHubAPIClientProtocol
    private let dateService: DateService
    private let pathMatcher: GitHubContentPathMatcher
    private let detailCache: GitHubCommitDetailCache
    private let owner: String
    private let repository: String
    private let mainRef: String
    private let lookbackDays: Int
    private let commitListLimit: Int
    private let pullRequestLimit: Int
    private let maxRequestsPerVerification: Int

    init(
        client: GitHubAPIClientProtocol = GitHubAPIClient(),
        dateService: DateService = DateService(),
        pathMatcher: GitHubContentPathMatcher = GitHubContentPathMatcher(),
        detailCache: GitHubCommitDetailCache = GitHubCommitDetailCache(),
        owner: String = "sssuunnnm",
        repository: String = "dev-archive",
        mainRef: String = "main",
        lookbackDays: Int = 7,
        commitListLimit: Int = 30,
        pullRequestLimit: Int = 20,
        maxRequestsPerVerification: Int = 20
    ) {
        self.client = client
        self.dateService = dateService
        self.pathMatcher = pathMatcher
        self.detailCache = detailCache
        self.owner = owner
        self.repository = repository
        self.mainRef = mainRef
        self.lookbackDays = lookbackDays
        self.commitListLimit = commitListLimit
        self.pullRequestLimit = pullRequestLimit
        self.maxRequestsPerVerification = maxRequestsPerVerification
    }

    func verify(now: Date = .now) async -> Result<GitHubVerificationResult, GitHubVerificationFailure> {
        do {
            let result = try await verifiedActivity(now: now)
            return .success(result)
        } catch let failure as GitHubVerificationFailure {
            return .failure(failure)
        } catch let error as GitHubAPIError {
            return .failure(Self.failure(from: error))
        } catch {
            return .failure(.unknown)
        }
    }

    func verifiedActivity(now: Date = .now) async throws -> GitHubVerificationResult {
        let since = verificationStartDate(now: now)
        var budget = GitHubVerificationBudget(maxRequestsPerVerification: maxRequestsPerVerification)
        var candidates: [GitHubCommitSummary] = []

        candidates += try await pagedCommits(
            since: since,
            budget: &budget
        ) { page in
            try await client.commits(
                owner: owner,
                repository: repository,
                ref: mainRef,
                since: since,
                perPage: commitListLimit,
                page: page
            )
        }

        let pullRequests = try await pagedPullRequests(budget: &budget)

        for pullRequest in pullRequests {
            candidates += try await pagedCommits(
                since: since,
                budget: &budget
            ) { page in
                try await client.pullRequestCommits(
                    owner: owner,
                    repository: repository,
                    number: pullRequest.number,
                    perPage: commitListLimit,
                    page: page
                )
            }
        }

        let dedupedCandidates = deduplicated(candidates)
            .filter { $0.timestamp >= since }

        var verifiedDateKeys = Set<String>()

        for candidate in dedupedCandidates {
            let containsContentPath = try await containsContentPath(for: candidate.sha, budget: &budget)
            guard containsContentPath else {
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

    private func pagedPullRequests(budget: inout GitHubVerificationBudget) async throws -> [GitHubPullRequest] {
        var pageNumber = 1
        var pullRequests: [GitHubPullRequest] = []

        while true {
            try budget.consume()
            let page = try await client.openPullRequests(
                owner: owner,
                repository: repository,
                perPage: pullRequestLimit,
                page: pageNumber
            )
            pullRequests += page.values

            guard page.hasNextPage else {
                return pullRequests
            }

            pageNumber += 1
        }
    }

    private func pagedCommits(
        since: Date,
        budget: inout GitHubVerificationBudget,
        fetch: (Int) async throws -> GitHubPage<GitHubCommitSummary>
    ) async throws -> [GitHubCommitSummary] {
        var pageNumber = 1
        var commits: [GitHubCommitSummary] = []

        while true {
            try budget.consume()
            let page = try await fetch(pageNumber)
            commits += page.values.filter { $0.timestamp >= since }

            if page.values.contains(where: { $0.timestamp < since }) {
                return commits
            }

            guard page.hasNextPage else {
                return commits
            }

            pageNumber += 1
        }
    }

    private func containsContentPath(for sha: String, budget: inout GitHubVerificationBudget) async throws -> Bool {
        if let cached = await detailCache.contentPathResult(for: sha) {
            return cached
        }

        try budget.consume()
        let detail = try await client.commitDetail(
            owner: owner,
            repository: repository,
            sha: sha
        )
        let containsContentPath = pathMatcher.containsWritingContentPath(detail.filenames)
        await detailCache.store(containsContentPath, for: sha)
        return containsContentPath
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
