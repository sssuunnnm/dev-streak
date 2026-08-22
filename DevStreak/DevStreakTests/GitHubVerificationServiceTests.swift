//
//  GitHubVerificationServiceTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

struct GitHubVerificationServiceTests {
    @Test func shaDedupeKeepsFirstOccurrence() {
        let service = Self.service(client: FakeGitHubAPIClient())
        let commits = [
            GitHubCommitSummary(sha: "a", timestamp: Self.noon("2026-08-22")),
            GitHubCommitSummary(sha: "b", timestamp: Self.noon("2026-08-22")),
            GitHubCommitSummary(sha: "a", timestamp: Self.noon("2026-08-21"))
        ]

        let deduped = service.deduplicated(commits)

        #expect(deduped.map(\.sha) == ["a", "b"])
        #expect(deduped.first?.timestamp == Self.noon("2026-08-22"))
    }

    @Test func mainAndPullRequestDuplicateCommitUsesOneDetailCall() async throws {
        let client = FakeGitHubAPIClient()
        client.mainCommitPages = [
            GitHubPage(values: [Self.commit("shared", "2026-08-22")], hasNextPage: false)
        ]
        client.pullRequestPages = [
            GitHubPage(values: [GitHubPullRequest(number: 1)], hasNextPage: false)
        ]
        client.pullRequestCommitPages[1] = [
            GitHubPage(values: [Self.commit("shared", "2026-08-22")], hasNextPage: false)
        ]
        client.details["shared"] = GitHubCommitDetail(sha: "shared", filenames: ["src/content/articles/post.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
        #expect(client.detailSHAs == ["shared"])
    }

    @Test func timestampIsConvertedToLocalDateKey() async throws {
        let client = FakeGitHubAPIClient()
        client.mainCommitPages = [
            GitHubPage(values: [
                GitHubCommitSummary(sha: "late-utc", timestamp: Self.utcDate("2026-08-21T16:10:00Z"))
            ], hasNextPage: false)
        ]
        client.details["late-utc"] = GitHubCommitDetail(sha: "late-utc", filenames: ["src/content/snippets/timezone.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
    }

    @Test func unrelatedCommitDoesNotVerifyDate() async throws {
        let client = FakeGitHubAPIClient()
        client.mainCommitPages = [
            GitHubPage(values: [Self.commit("code", "2026-08-22")], hasNextPage: false)
        ]
        client.details["code"] = GitHubCommitDetail(sha: "code", filenames: ["src/components/Card.tsx"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys.isEmpty)
    }

    @Test func apiRateLimitMapsToFailureState() async {
        let client = FakeGitHubAPIClient()
        client.error = .rateLimited(nil)

        let result = await Self.service(client: client).verify(now: Self.noon("2026-08-22"))

        #expect(result == .failure(.rateLimited(nil)))
    }

    @Test func openPullRequestCommitCanVerifyDate() async throws {
        let client = FakeGitHubAPIClient()
        client.pullRequestPages = [
            GitHubPage(values: [GitHubPullRequest(number: 7)], hasNextPage: false)
        ]
        client.pullRequestCommitPages[7] = [
            GitHubPage(values: [Self.commit("pr-content", "2026-08-22")], hasNextPage: false)
        ]
        client.details["pr-content"] = GitHubCommitDetail(sha: "pr-content", filenames: ["src/content/projects/widget.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
    }

    @Test func mainCommitOnSecondPageIsDiscovered() async throws {
        let client = FakeGitHubAPIClient()
        client.mainCommitPages = [
            GitHubPage(values: [Self.commit("docs", "2026-08-22")], hasNextPage: true),
            GitHubPage(values: [Self.commit("content", "2026-08-22")], hasNextPage: false)
        ]
        client.details["docs"] = GitHubCommitDetail(sha: "docs", filenames: ["README.md"])
        client.details["content"] = GitHubCommitDetail(sha: "content", filenames: ["src/content/articles/page-two.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
        #expect(client.mainCommitRequestedPages == [1, 2])
    }

    @Test func openPullRequestOnSecondPageIsDiscovered() async throws {
        let client = FakeGitHubAPIClient()
        client.pullRequestPages = [
            GitHubPage(values: [GitHubPullRequest(number: 1)], hasNextPage: true),
            GitHubPage(values: [GitHubPullRequest(number: 2)], hasNextPage: false)
        ]
        client.pullRequestCommitPages[1] = [
            GitHubPage(values: [], hasNextPage: false)
        ]
        client.pullRequestCommitPages[2] = [
            GitHubPage(values: [Self.commit("pr2", "2026-08-22")], hasNextPage: false)
        ]
        client.details["pr2"] = GitHubCommitDetail(sha: "pr2", filenames: ["src/content/references/pr.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
        #expect(client.pullRequestRequestedPages == [1, 2])
    }

    @Test func pullRequestCommitOnSecondPageIsDiscovered() async throws {
        let client = FakeGitHubAPIClient()
        client.pullRequestPages = [
            GitHubPage(values: [GitHubPullRequest(number: 9)], hasNextPage: false)
        ]
        client.pullRequestCommitPages[9] = [
            GitHubPage(values: [Self.commit("pr-docs", "2026-08-22")], hasNextPage: true),
            GitHubPage(values: [Self.commit("pr-content", "2026-08-22")], hasNextPage: false)
        ]
        client.details["pr-docs"] = GitHubCommitDetail(sha: "pr-docs", filenames: ["README.md"])
        client.details["pr-content"] = GitHubCommitDetail(sha: "pr-content", filenames: ["src/content/snippets/pr.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
        #expect(client.pullRequestCommitRequestedPages[9] == [1, 2])
    }

    @Test func paginationStopsWhenOlderThanLookbackReached() async throws {
        let client = FakeGitHubAPIClient()
        client.mainCommitPages = [
            GitHubPage(values: [Self.commit("recent", "2026-08-22")], hasNextPage: true),
            GitHubPage(values: [Self.commit("old", "2026-08-10")], hasNextPage: true)
        ]
        client.details["recent"] = GitHubCommitDetail(sha: "recent", filenames: ["README.md"])

        _ = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(client.mainCommitRequestedPages == [1, 2])
    }

    @Test func verificationDoesNotExceedMaxRequestBudget() async {
        let client = FakeGitHubAPIClient()
        client.mainCommitPages = [
            GitHubPage(values: [
                Self.commit("a", "2026-08-22"),
                Self.commit("b", "2026-08-22"),
                Self.commit("c", "2026-08-22")
            ], hasNextPage: false)
        ]

        let result = await Self.service(client: client, maxRequests: 3).verify(now: Self.noon("2026-08-22"))

        #expect(result == .failure(.budgetExceeded))
        #expect(client.totalRequestCount == 3)
    }

    @Test func budgetExceededDoesNotReturnPartialVerification() async {
        let client = FakeGitHubAPIClient()
        client.mainCommitPages = [
            GitHubPage(values: [
                Self.commit("content", "2026-08-22"),
                Self.commit("second", "2026-08-22")
            ], hasNextPage: false)
        ]
        client.details["content"] = GitHubCommitDetail(sha: "content", filenames: ["src/content/articles/ok.md"])

        let result = await Self.service(client: client, maxRequests: 3).verify(now: Self.noon("2026-08-22"))

        #expect(result == .failure(.budgetExceeded))
    }

    @Test func detailCacheAvoidsRepeatedRequestForSameSHAAcrossRuns() async throws {
        let client = FakeGitHubAPIClient()
        let cache = GitHubCommitDetailCache()
        client.mainCommitPages = [
            GitHubPage(values: [Self.commit("cached", "2026-08-22")], hasNextPage: false)
        ]
        client.details["cached"] = GitHubCommitDetail(sha: "cached", filenames: ["src/content/articles/cache.md"])
        let service = Self.service(client: client, cache: cache)

        _ = try await service.verifiedActivity(now: Self.noon("2026-08-22"))
        _ = try await service.verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(client.detailSHAs == ["cached"])
    }

    private static func service(
        client: FakeGitHubAPIClient,
        cache: GitHubCommitDetailCache = GitHubCommitDetailCache(),
        maxRequests: Int = 20
    ) -> GitHubVerificationService {
        GitHubVerificationService(
            client: client,
            dateService: DateService(calendar: calendar),
            detailCache: cache,
            lookbackDays: 7,
            maxRequestsPerVerification: maxRequests
        )
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private static func commit(_ sha: String, _ dateKey: String) -> GitHubCommitSummary {
        GitHubCommitSummary(sha: sha, timestamp: noon(dateKey))
    }

    private static func noon(_ dateKey: String) -> Date {
        let parts = dateKey.split(separator: "-").compactMap { Int(String($0)) }
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: 12
        ))!
    }

    private static func utcDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

final class FakeGitHubAPIClient: GitHubAPIClientProtocol {
    var mainCommitPages: [GitHubPage<GitHubCommitSummary>] = []
    var pullRequestPages: [GitHubPage<GitHubPullRequest>] = []
    var pullRequestCommitPages: [Int: [GitHubPage<GitHubCommitSummary>]] = [:]
    var details: [String: GitHubCommitDetail] = [:]
    var detailSHAs: [String] = []
    var mainCommitRequestedPages: [Int] = []
    var pullRequestRequestedPages: [Int] = []
    var pullRequestCommitRequestedPages: [Int: [Int]] = [:]
    var error: GitHubAPIError?

    var totalRequestCount: Int {
        mainCommitRequestedPages.count
        + pullRequestRequestedPages.count
        + pullRequestCommitRequestedPages.values.reduce(0) { $0 + $1.count }
        + detailSHAs.count
    }

    func commits(owner: String, repository: String, ref: String, since: Date?, perPage: Int, page: Int) async throws -> GitHubPage<GitHubCommitSummary> {
        if let error {
            throw error
        }

        mainCommitRequestedPages.append(page)
        return Self.page(mainCommitPages, page: page)
    }

    func openPullRequests(owner: String, repository: String, perPage: Int, page: Int) async throws -> GitHubPage<GitHubPullRequest> {
        if let error {
            throw error
        }

        pullRequestRequestedPages.append(page)
        return Self.page(pullRequestPages, page: page)
    }

    func pullRequestCommits(owner: String, repository: String, number: Int, perPage: Int, page: Int) async throws -> GitHubPage<GitHubCommitSummary> {
        if let error {
            throw error
        }

        pullRequestCommitRequestedPages[number, default: []].append(page)
        return Self.page(pullRequestCommitPages[number] ?? [], page: page)
    }

    func commitDetail(owner: String, repository: String, sha: String) async throws -> GitHubCommitDetail {
        if let error {
            throw error
        }

        detailSHAs.append(sha)
        return details[sha] ?? GitHubCommitDetail(sha: sha, filenames: [])
    }

    private static func page<T>(_ pages: [GitHubPage<T>], page: Int) -> GitHubPage<T> {
        guard pages.indices.contains(page - 1) else {
            return GitHubPage(values: [], hasNextPage: false)
        }

        return pages[page - 1]
    }
}
