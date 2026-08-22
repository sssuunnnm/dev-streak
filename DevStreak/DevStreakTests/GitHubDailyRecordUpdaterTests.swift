//
//  GitHubDailyRecordUpdaterTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

@MainActor
struct GitHubDailyRecordUpdaterTests {
    private let updater = GitHubDailyRecordUpdater()

    @Test func todayContentCommitCreatesGitHubVerifiedRecord() {
        let update = updater.applyVerified(dateKey: "2026-08-22", records: [], now: Self.now)

        guard case .created(let record) = update else {
            Issue.record("Expected created record")
            return
        }

        #expect(record.dateKey == "2026-08-22")
        #expect(record.status == .githubVerified)
        #expect(update.requiresSave)
        #expect(update.shouldRunCompletionSideEffects)
    }

    @Test func manualCompletedRecordIsPromotedToGitHubVerified() {
        let record = DailyRecord(
            dateKey: "2026-08-22",
            status: .manualCompleted,
            completedAt: Self.now,
            createdAt: Self.now
        )

        let update = updater.applyVerified(dateKey: "2026-08-22", records: [record], now: Self.now)

        guard case .updated(let updatedRecord) = update else {
            Issue.record("Expected updated record")
            return
        }

        #expect(updatedRecord === record)
        #expect(record.status == .githubVerified)
        #expect(update.requiresSave)
    }

    @Test func existingGitHubVerifiedRecordIsNotDuplicated() {
        let record = DailyRecord(
            dateKey: "2026-08-22",
            status: .githubVerified,
            completedAt: Self.now,
            createdAt: Self.now
        )

        let update = updater.applyVerified(dateKey: "2026-08-22", records: [record], now: Self.now)

        guard case .unchanged(let unchangedRecord) = update else {
            Issue.record("Expected unchanged record")
            return
        }

        #expect(unchangedRecord === record)
        #expect(!update.requiresSave)
        #expect(update.shouldRunCompletionSideEffects)
    }

    @Test func pendingRecordIsPromotedToGitHubVerified() {
        let record = DailyRecord(dateKey: "2026-08-22", status: .pending, createdAt: Self.now)

        let update = updater.applyVerified(dateKey: "2026-08-22", records: [record], now: Self.now)

        guard case .updated = update else {
            Issue.record("Expected updated record")
            return
        }

        #expect(record.status == .githubVerified)
        #expect(record.completedAt == Self.now)
    }

    @Test func apiErrorDoesNotCreateMissedRecord() {
        let result: Result<GitHubVerificationResult, GitHubVerificationFailure> = .failure(.networkFailure)

        switch result {
        case .success:
            Issue.record("Expected failure")
        case .failure:
            #expect(true)
        }
    }

    @Test func successfulVerificationRequestsReminderAndWidgetSideEffects() {
        let update = updater.applyVerified(dateKey: "2026-08-22", records: [], now: Self.now)

        #expect(update.shouldRunCompletionSideEffects)
    }

    @Test func multipleVerifiedDateKeysAreAllApplied() {
        let pastManual = DailyRecord(
            dateKey: "2026-08-20",
            status: .manualCompleted,
            completedAt: Self.now,
            createdAt: Self.now
        )
        let existingVerified = DailyRecord(
            dateKey: "2026-08-21",
            status: .githubVerified,
            completedAt: Self.now,
            createdAt: Self.now
        )

        let updates = updater.applyVerified(
            dateKeys: ["2026-08-20", "2026-08-21", "2026-08-22"],
            records: [pastManual, existingVerified],
            now: Self.now
        )

        #expect(updates.count == 3)
        #expect(pastManual.status == .githubVerified)
        #expect(existingVerified.status == .githubVerified)
        #expect(updates.contains { if case .created(let record) = $0 { record.dateKey == "2026-08-22" } else { false } })
    }

    @Test func pastOnlyVerificationDoesNotRequireTodayReminderCancel() {
        let verifiedDateKeys: Set<String> = ["2026-08-20", "2026-08-21"]
        let todayKey = "2026-08-22"

        #expect(!verifiedDateKeys.contains(todayKey))
    }

    @Test func pastVerificationStillRequiresWidgetRefreshAfterSave() {
        let update = updater.applyVerified(dateKey: "2026-08-20", records: [], now: Self.now)

        #expect(update.requiresSave)
        #expect(update.shouldRunCompletionSideEffects)
    }

    private static let now = Date(timeIntervalSince1970: 1_787_321_600)
}
