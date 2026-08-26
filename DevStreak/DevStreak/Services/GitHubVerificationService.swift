//
//  GitHubVerificationService.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation
import SwiftData

nonisolated enum GitHubVerificationFailure: Error, Equatable {
    case rateLimited(GitHubRateLimitDiagnostics?)
    case credentialUnavailable
    case unauthorizedOrForbidden
    case notFound
    case networkFailure
    case decodingFailure
    case budgetExceeded
    case unknown
}

nonisolated struct GitHubVerificationResult: Equatable {
    let verifiedDateKeys: Set<String>

    var hasActivity: Bool {
        !verifiedDateKeys.isEmpty
    }
}

nonisolated struct GitHubVerificationBudget {
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

nonisolated struct GitHubVerificationBudgetPolicy {
    let unauthenticatedRequestLimit: Int
    let authenticatedRequestLimit: Int

    init(
        unauthenticatedRequestLimit: Int = 20,
        authenticatedRequestLimit: Int = 120
    ) {
        self.unauthenticatedRequestLimit = unauthenticatedRequestLimit
        self.authenticatedRequestLimit = authenticatedRequestLimit
    }

    func requestLimit(hasAuthentication: Bool) -> Int {
        hasAuthentication ? authenticatedRequestLimit : unauthenticatedRequestLimit
    }
}

nonisolated enum GitHubVerificationDefaults {
    static let dashboardLookbackDays = 7
    static let backfillLookbackDays = 30
    static let authenticatedBackfillRequestLimit = 240
    static let authenticatedInitialBackfillRequestLimit = 1_000
}

nonisolated enum GitHubRepositoryConfiguration {
    static let owner = "sssuunnnm"
    static let name = "dev-archive"
    static let mainRef = "main"
    static let fullName = "\(owner)/\(name)"
    static let keychainAccount = "\(name).pat"
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

nonisolated struct GitHubVerificationService {
    private let client: GitHubAPIClientProtocol
    private let dateService: DateService
    private let pathMatcher: GitHubContentPathMatcher
    private let detailCache: GitHubCommitDetailCache
    private let owner: String
    private let repository: String
    private let mainRef: String
    private let lookbackDays: Int?
    private let commitListLimit: Int
    private let pullRequestLimit: Int
    private let maxRequestsPerVerification: Int?
    private let budgetPolicy: GitHubVerificationBudgetPolicy
    private let credentialStore: GitHubCredentialStore

    init(
        client: GitHubAPIClientProtocol = GitHubAPIClient(),
        dateService: DateService = DateService(),
        pathMatcher: GitHubContentPathMatcher = GitHubContentPathMatcher(),
        detailCache: GitHubCommitDetailCache = GitHubCommitDetailCache(),
        owner: String = GitHubRepositoryConfiguration.owner,
        repository: String = GitHubRepositoryConfiguration.name,
        mainRef: String = GitHubRepositoryConfiguration.mainRef,
        lookbackDays: Int? = GitHubVerificationDefaults.dashboardLookbackDays,
        commitListLimit: Int = 30,
        pullRequestLimit: Int = 20,
        maxRequestsPerVerification: Int? = nil,
        budgetPolicy: GitHubVerificationBudgetPolicy = GitHubVerificationBudgetPolicy(),
        credentialStore: GitHubCredentialStore = GitHubCredentialStore()
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
        self.budgetPolicy = budgetPolicy
        self.credentialStore = credentialStore
    }

    func verify(now: Date = .now) async -> Result<GitHubVerificationResult, GitHubVerificationFailure> {
        do {
            let result = try await verifiedActivity(now: now)
            return .success(result)
        } catch let failure as GitHubVerificationFailure {
            return .failure(failure)
        } catch let error as GitHubAPIError {
            return .failure(Self.failure(from: error))
        } catch is GitHubCredentialError {
            return .failure(.credentialUnavailable)
        } catch {
            return .failure(.unknown)
        }
    }

    func verifiedActivity(now: Date = .now) async throws -> GitHubVerificationResult {
        let since = verificationStartDate(now: now)
        var budget = GitHubVerificationBudget(maxRequestsPerVerification: try requestLimit())
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
            .filter { candidate in
                guard let since else {
                    return true
                }

                return candidate.timestamp >= since
            }

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

    private func requestLimit() throws -> Int {
        if let maxRequestsPerVerification {
            return maxRequestsPerVerification
        }

        return budgetPolicy.requestLimit(hasAuthentication: try credentialStore.hasToken())
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
        since: Date?,
        budget: inout GitHubVerificationBudget,
        fetch: (Int) async throws -> GitHubPage<GitHubCommitSummary>
    ) async throws -> [GitHubCommitSummary] {
        var pageNumber = 1
        var commits: [GitHubCommitSummary] = []

        while true {
            try budget.consume()
            let page = try await fetch(pageNumber)
            if let since {
                commits += page.values.filter { $0.timestamp >= since }

                if page.values.contains(where: { $0.timestamp < since }) {
                    return commits
                }
            } else {
                commits += page.values
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

    private func verificationStartDate(now: Date) -> Date? {
        guard let lookbackDays else {
            return nil
        }

        let todayKey = dateService.todayKey(now: now)
        guard let startKey = dateService.addingDays(-lookbackDays, to: todayKey),
              let startDate = dateService.date(from: startKey) else {
            return now
        }

        return startDate
    }

    private static func failure(from error: GitHubAPIError) -> GitHubVerificationFailure {
        switch error {
        case .rateLimited(let diagnostics):
            return .rateLimited(diagnostics)
        case .credentialUnavailable:
            return .credentialUnavailable
        case .unauthorized, .forbidden, .unauthorizedOrForbidden:
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

nonisolated enum GitHubBackfillFailure: Error, Equatable {
    case verification(GitHubVerificationFailure)
    case saveFailed
}

nonisolated struct GitHubBackfillResult: Equatable {
    let verifiedDateKeys: Set<String>
    let changedDateKeys: Set<String>

    var changedDayCount: Int {
        changedDateKeys.count
    }
}

@MainActor
struct GitHubBackfillService {
    private let verify: (Date) async -> Result<GitHubVerificationResult, GitHubVerificationFailure>
    private let dateService: DateService
    private let dailyRecordUpdater: GitHubDailyRecordUpdater
    private let updateWidgetSnapshot: ([DailyRecord], [Idea], Date) -> Void
    private let cancelTodayReminders: (Date) async -> Void

    init(
        verificationService: GitHubVerificationService? = nil,
        dateService: DateService? = nil,
        dailyRecordUpdater: GitHubDailyRecordUpdater? = nil,
        widgetSnapshotService: WidgetSnapshotService? = nil,
        reminderNotificationService: ReminderNotificationService? = nil,
        lookbackDays: Int? = GitHubVerificationDefaults.backfillLookbackDays,
        authenticatedRequestLimit: Int = GitHubVerificationDefaults.authenticatedBackfillRequestLimit
    ) {
        let resolvedDateService = dateService ?? DateService()
        let verificationService = verificationService ?? GitHubVerificationService(
            dateService: resolvedDateService,
            lookbackDays: lookbackDays,
            budgetPolicy: GitHubVerificationBudgetPolicy(
                authenticatedRequestLimit: authenticatedRequestLimit
            )
        )
        let dailyRecordUpdater = dailyRecordUpdater ?? GitHubDailyRecordUpdater()
        let widgetSnapshotService = widgetSnapshotService ?? WidgetSnapshotService(dateService: resolvedDateService)
        let reminderNotificationService = reminderNotificationService ?? ReminderNotificationService(dateService: resolvedDateService)

        self.init(
            verify: { now in
                await verificationService.verify(now: now)
            },
            dateService: resolvedDateService,
            dailyRecordUpdater: dailyRecordUpdater,
            updateWidgetSnapshot: { records, ideas, now in
                widgetSnapshotService.updateSnapshot(records: records, ideas: ideas, now: now)
            },
            cancelTodayReminders: { now in
                await reminderNotificationService.cancelTodayReminders(now: now)
            }
        )
    }

    init(
        verify: @escaping (Date) async -> Result<GitHubVerificationResult, GitHubVerificationFailure>,
        dateService: DateService,
        dailyRecordUpdater: GitHubDailyRecordUpdater? = nil,
        updateWidgetSnapshot: @escaping ([DailyRecord], [Idea], Date) -> Void,
        cancelTodayReminders: @escaping (Date) async -> Void
    ) {
        self.verify = verify
        self.dateService = dateService
        self.dailyRecordUpdater = dailyRecordUpdater ?? GitHubDailyRecordUpdater()
        self.updateWidgetSnapshot = updateWidgetSnapshot
        self.cancelTodayReminders = cancelTodayReminders
    }

    func backfill(
        records: [DailyRecord],
        ideas: [Idea],
        modelContext: ModelContext,
        now: Date = .now
    ) async -> Result<GitHubBackfillResult, GitHubBackfillFailure> {
        let verificationResult = await verify(now)

        switch verificationResult {
        case .failure(let failure):
            return .failure(.verification(failure))
        case .success(let result):
            let updates = dailyRecordUpdater.applyVerified(
                dateKeys: result.verifiedDateKeys,
                records: records,
                now: now
            )
            let changedDateKeys = Set(updates.compactMap { update -> String? in
                guard update.requiresSave else {
                    return nil
                }

                return update.record.dateKey
            })

            var snapshotRecords = records
            for update in updates {
                if case .created(let record) = update {
                    modelContext.insert(record)
                    snapshotRecords.append(record)
                }
            }

            do {
                if updates.contains(where: \.requiresSave) {
                    try modelContext.save()
                }

                updateWidgetSnapshot(snapshotRecords, ideas, now)

                if result.verifiedDateKeys.contains(dateService.todayKey(now: now)) {
                    await cancelTodayReminders(now)
                }

                return .success(GitHubBackfillResult(
                    verifiedDateKeys: result.verifiedDateKeys,
                    changedDateKeys: changedDateKeys
                ))
            } catch {
                modelContext.rollback()
                return .failure(.saveFailed)
            }
        }
    }
}
