//
//  GitHubDailyRecordUpdaterTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import SwiftData
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

    @Test func backfillAppliesMultipleVerifiedDateKeysInOneSave() async throws {
        let context = try Self.inMemoryContext()
        let manual = DailyRecord(
            dateKey: "2026-08-03",
            status: .manualCompleted,
            completedAt: Self.noon("2026-08-03"),
            createdAt: Self.noon("2026-08-03")
        )
        let existing = DailyRecord(
            dateKey: "2026-08-05",
            status: .githubVerified,
            completedAt: Self.noon("2026-08-05"),
            createdAt: Self.noon("2026-08-05")
        )
        context.insert(manual)
        context.insert(existing)
        try context.save()

        var widgetRefreshCount = 0
        var reminderCancelCount = 0
        let service = GitHubBackfillService(
            verify: { _ in
                .success(GitHubVerificationResult(verifiedDateKeys: ["2026-08-03", "2026-08-05", "2026-08-07"]))
            },
            dateService: DateService(calendar: Self.calendar),
            updateWidgetSnapshot: { _, _, _ in
                widgetRefreshCount += 1
            },
            cancelTodayReminders: { _ in
                reminderCancelCount += 1
            }
        )

        let result = await service.backfill(
            records: try Self.records(in: context),
            ideas: [],
            modelContext: context,
            now: Self.noon("2026-08-22")
        )
        let records = try Self.records(in: context)

        #expect(result == .success(GitHubBackfillResult(
            verifiedDateKeys: ["2026-08-03", "2026-08-05", "2026-08-07"],
            changedDateKeys: ["2026-08-03", "2026-08-07"]
        )))
        #expect(records.count == 3)
        #expect(records.allSatisfy { $0.status == .githubVerified })
        #expect(widgetRefreshCount == 1)
        #expect(reminderCancelCount == 0)
    }

    @Test func backfillFailureDoesNotPersistPartialRecords() async throws {
        let context = try Self.inMemoryContext()
        var widgetRefreshCount = 0
        var reminderCancelCount = 0
        let service = GitHubBackfillService(
            verify: { _ in
                .failure(.budgetExceeded)
            },
            dateService: DateService(calendar: Self.calendar),
            updateWidgetSnapshot: { _, _, _ in
                widgetRefreshCount += 1
            },
            cancelTodayReminders: { _ in
                reminderCancelCount += 1
            }
        )

        let result = await service.backfill(
            records: [],
            ideas: [],
            modelContext: context,
            now: Self.noon("2026-08-22")
        )

        #expect(result == .failure(.verification(.budgetExceeded)))
        #expect(try Self.records(in: context).isEmpty)
        #expect(widgetRefreshCount == 0)
        #expect(reminderCancelCount == 0)
    }

    @Test func backfillNoNewRecordsIsSuccessfulAndRefreshesWidget() async throws {
        let context = try Self.inMemoryContext()
        let existing = DailyRecord(
            dateKey: "2026-08-03",
            status: .githubVerified,
            completedAt: Self.noon("2026-08-03"),
            createdAt: Self.noon("2026-08-03")
        )
        context.insert(existing)
        try context.save()

        var widgetRefreshCount = 0
        let service = GitHubBackfillService(
            verify: { _ in
                .success(GitHubVerificationResult(verifiedDateKeys: ["2026-08-03"]))
            },
            dateService: DateService(calendar: Self.calendar),
            updateWidgetSnapshot: { _, _, _ in
                widgetRefreshCount += 1
            },
            cancelTodayReminders: { _ in }
        )

        let result = await service.backfill(
            records: try Self.records(in: context),
            ideas: [],
            modelContext: context,
            now: Self.noon("2026-08-22")
        )

        #expect(result == .success(GitHubBackfillResult(
            verifiedDateKeys: ["2026-08-03"],
            changedDateKeys: []
        )))
        #expect(try Self.records(in: context).count == 1)
        #expect(widgetRefreshCount == 1)
    }

    @Test func backfillCancelsReminderOnlyWhenTodayIsIncluded() async throws {
        let context = try Self.inMemoryContext()
        var cancelledDates: [Date] = []
        let service = GitHubBackfillService(
            verify: { _ in
                .success(GitHubVerificationResult(verifiedDateKeys: ["2026-08-21", "2026-08-22"]))
            },
            dateService: DateService(calendar: Self.calendar),
            updateWidgetSnapshot: { _, _, _ in },
            cancelTodayReminders: { date in
                cancelledDates.append(date)
            }
        )
        let now = Self.noon("2026-08-22")

        _ = await service.backfill(
            records: [],
            ideas: [],
            modelContext: context,
            now: now
        )

        #expect(cancelledDates == [now])
    }

    private static let now = Date(timeIntervalSince1970: 1_787_321_600)

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private static func inMemoryContext() throws -> ModelContext {
        let schema = Schema([DailyRecord.self, Idea.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private static func records(in context: ModelContext) throws -> [DailyRecord] {
        try context.fetch(FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.dateKey)]))
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
}
