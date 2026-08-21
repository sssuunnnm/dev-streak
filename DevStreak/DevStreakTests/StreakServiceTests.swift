//
//  StreakServiceTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/21/26.
//

import Foundation
import Testing
@testable import DevStreak

@MainActor
struct StreakServiceTests {
    @Test func currentStreakIncludesTodayWhenCompleted() {
        let service = Self.service
        let records = [
            Self.record("2026-08-19"),
            Self.record("2026-08-20"),
            Self.record("2026-08-21")
        ]

        #expect(service.currentStreak(records: records, now: Self.noon("2026-08-21")) == 3)
    }

    @Test func currentStreakDoesNotDropToZeroJustBecauseTodayIsIncomplete() {
        let service = Self.service
        let records = [
            Self.record("2026-08-18"),
            Self.record("2026-08-19"),
            Self.record("2026-08-20")
        ]

        #expect(service.currentStreak(records: records, now: Self.noon("2026-08-21")) == 3)
    }

    @Test func currentStreakDropsWhenPreviousDayWasIncomplete() {
        let service = Self.service
        let records = [
            Self.record("2026-08-18"),
            Self.record("2026-08-19")
        ]

        #expect(service.currentStreak(records: records, now: Self.noon("2026-08-21")) == 0)
    }

    @Test func pendingRecordsDoNotCountAsCompleted() {
        let service = Self.service
        let records = [
            Self.record("2026-08-20"),
            Self.record("2026-08-21", status: .pending)
        ]

        #expect(service.currentStreak(records: records, now: Self.noon("2026-08-21")) == 1)
    }

    @Test func bestStreakFindsLongestCompletedRun() {
        let service = Self.service
        let records = [
            Self.record("2026-08-01"),
            Self.record("2026-08-02"),
            Self.record("2026-08-04"),
            Self.record("2026-08-05"),
            Self.record("2026-08-06")
        ]

        #expect(service.bestStreak(records: records) == 3)
    }

    @Test func githubVerifiedCountsAsCompletedStatusOnly() {
        let service = Self.service
        let records = [
            Self.record("2026-08-20"),
            Self.record("2026-08-21", status: .githubVerified)
        ]

        #expect(service.currentStreak(records: records, now: Self.noon("2026-08-21")) == 2)
    }

    private static var service: StreakService {
        StreakService(dateService: DateService(calendar: calendar))
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private static func record(_ dateKey: String, status: DailyRecordStatus = .manualCompleted) -> DailyRecord {
        DailyRecord(dateKey: dateKey, status: status, completedAt: noon(dateKey), createdAt: noon(dateKey))
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
