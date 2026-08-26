//
//  CalendarMonthRangePolicyTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/26/26.
//

import Foundation
import Testing
@testable import DevStreak

@MainActor
struct CalendarMonthRangePolicyTests {
    @Test func disconnectedTrackingOnlyAllowsCurrentMonth() {
        let policy = Self.policy
        let now = Self.noon("2026-08-26")
        let oldRecord = Self.record("2026-07-15")

        let earliestMonth = policy.earliestVisibleMonth(
            now: now,
            records: [oldRecord],
            isTrackingEnabled: false,
            repositoryCreatedAt: Self.noon("2026-07-01")
        )

        #expect(Self.dateService.dateKey(for: earliestMonth) == "2026-08-01")
    }

    @Test func repositoryCreationMonthSetsEarliestVisibleMonth() {
        let policy = Self.policy
        let now = Self.noon("2026-08-26")

        let earliestMonth = policy.earliestVisibleMonth(
            now: now,
            records: [],
            isTrackingEnabled: true,
            repositoryCreatedAt: Self.noon("2026-07-15")
        )

        #expect(Self.dateService.dateKey(for: earliestMonth) == "2026-07-01")
    }

    @Test func earliestVisibleMonthDoesNotExceedThreeYearLookback() {
        let policy = Self.policy
        let now = Self.noon("2026-08-26")

        let earliestMonth = policy.earliestVisibleMonth(
            now: now,
            records: [],
            isTrackingEnabled: true,
            repositoryCreatedAt: Self.noon("2020-01-01")
        )

        #expect(Self.dateService.dateKey(for: earliestMonth) == "2023-08-01")
    }

    @Test func clampedMonthStaysInsideAllowedRange() {
        let policy = Self.policy
        let now = Self.noon("2026-08-26")

        let clampedPast = policy.clampedMonth(
            Self.noon("2026-06-01"),
            now: now,
            records: [],
            isTrackingEnabled: true,
            repositoryCreatedAt: Self.noon("2026-07-15")
        )
        let clampedFuture = policy.clampedMonth(
            Self.noon("2026-09-01"),
            now: now,
            records: [],
            isTrackingEnabled: true,
            repositoryCreatedAt: Self.noon("2026-07-15")
        )

        #expect(Self.dateService.dateKey(for: clampedPast) == "2026-07-01")
        #expect(Self.dateService.dateKey(for: clampedFuture) == "2026-08-01")
    }

    private static var policy: CalendarMonthRangePolicy {
        CalendarMonthRangePolicy(dateService: dateService)
    }

    private static var dateService: DateService {
        DateService(calendar: calendar)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func record(_ dateKey: String) -> DailyRecord {
        DailyRecord(dateKey: dateKey, status: .githubVerified, completedAt: noon(dateKey), createdAt: noon(dateKey))
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
