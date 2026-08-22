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
        client.mainCommits = [GitHubCommitSummary(sha: "shared", timestamp: Self.noon("2026-08-22"))]
        client.pullRequests = [GitHubPullRequest(number: 1)]
        client.pullRequestCommits[1] = [GitHubCommitSummary(sha: "shared", timestamp: Self.noon("2026-08-22"))]
        client.details["shared"] = GitHubCommitDetail(sha: "shared", filenames: ["src/content/articles/post.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
        #expect(client.detailSHAs == ["shared"])
    }

    @Test func timestampIsConvertedToLocalDateKey() async throws {
        let client = FakeGitHubAPIClient()
        client.mainCommits = [
            GitHubCommitSummary(sha: "late-utc", timestamp: Self.utcDate("2026-08-21T16:10:00Z"))
        ]
        client.details["late-utc"] = GitHubCommitDetail(sha: "late-utc", filenames: ["src/content/snippets/timezone.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
    }

    @Test func unrelatedCommitDoesNotVerifyDate() async throws {
        let client = FakeGitHubAPIClient()
        client.mainCommits = [GitHubCommitSummary(sha: "code", timestamp: Self.noon("2026-08-22"))]
        client.details["code"] = GitHubCommitDetail(sha: "code", filenames: ["src/components/Card.tsx"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys.isEmpty)
    }

    @Test func apiRateLimitMapsToFailureState() async {
        let client = FakeGitHubAPIClient()
        client.error = .rateLimited

        let result = await Self.service(client: client).verify(now: Self.noon("2026-08-22"))

        #expect(result == .failure(.rateLimited))
    }

    @Test func openPullRequestCommitCanVerifyDate() async throws {
        let client = FakeGitHubAPIClient()
        client.pullRequests = [GitHubPullRequest(number: 7)]
        client.pullRequestCommits[7] = [GitHubCommitSummary(sha: "pr-content", timestamp: Self.noon("2026-08-22"))]
        client.details["pr-content"] = GitHubCommitDetail(sha: "pr-content", filenames: ["src/content/projects/widget.md"])

        let result = try await Self.service(client: client).verifiedActivity(now: Self.noon("2026-08-22"))

        #expect(result.verifiedDateKeys == ["2026-08-22"])
    }

    private static func service(client: FakeGitHubAPIClient) -> GitHubVerificationService {
        GitHubVerificationService(
            client: client,
            dateService: DateService(calendar: calendar),
            lookbackDays: 3
        )
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
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
    var mainCommits: [GitHubCommitSummary] = []
    var pullRequests: [GitHubPullRequest] = []
    var pullRequestCommits: [Int: [GitHubCommitSummary]] = [:]
    var details: [String: GitHubCommitDetail] = [:]
    var detailSHAs: [String] = []
    var error: GitHubAPIError?

    func commits(owner: String, repository: String, ref: String, since: Date?, perPage: Int) async throws -> [GitHubCommitSummary] {
        if let error {
            throw error
        }

        return mainCommits
    }

    func openPullRequests(owner: String, repository: String, perPage: Int) async throws -> [GitHubPullRequest] {
        if let error {
            throw error
        }

        return pullRequests
    }

    func pullRequestCommits(owner: String, repository: String, number: Int, perPage: Int) async throws -> [GitHubCommitSummary] {
        if let error {
            throw error
        }

        return pullRequestCommits[number] ?? []
    }

    func commitDetail(owner: String, repository: String, sha: String) async throws -> GitHubCommitDetail {
        if let error {
            throw error
        }

        detailSHAs.append(sha)
        return details[sha] ?? GitHubCommitDetail(sha: sha, filenames: [])
    }
}
