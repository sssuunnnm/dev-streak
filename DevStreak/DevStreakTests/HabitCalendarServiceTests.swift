//
//  HabitCalendarServiceTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

@MainActor
struct HabitCalendarServiceTests {
    @Test func completedStatusRequiresGitHubVerified() {
        let service = Self.service
        let now = Self.noon("2026-08-21")
        let records = [
            Self.record("2026-08-20", status: .manualCompleted),
            Self.record("2026-08-21", status: .githubVerified)
        ]

        #expect(service.status(for: "2026-08-20", records: records, now: now) == .missed)
        #expect(service.status(for: "2026-08-21", records: records, now: now) == .completed)
    }

    @Test func pastIncompleteDayIsMissed() {
        let service = Self.service
        let now = Self.noon("2026-08-21")

        #expect(service.status(for: "2026-08-20", records: [], now: now) == .missed)
    }

    @Test func daysBeforeTrackingStartAreUntracked() {
        let service = Self.service
        let now = Self.noon("2026-08-21")
        let trackingStartDate = Self.noon("2026-08-10")

        #expect(service.status(
            for: "2026-08-09",
            records: [],
            now: now,
            trackingStartDate: trackingStartDate
        ) == .untracked)
        #expect(service.status(
            for: "2026-08-10",
            records: [],
            now: now,
            trackingStartDate: trackingStartDate
        ) == .missed)
    }

    @Test func todayIncompleteDayIsPendingNotMissed() {
        let service = Self.service
        let now = Self.noon("2026-08-21")

        #expect(service.status(for: "2026-08-21", records: [], now: now) == .pending)
    }

    @Test func futureDayIsFutureNotPendingOrMissed() {
        let service = Self.service
        let now = Self.noon("2026-08-21")

        #expect(service.status(for: "2026-08-22", records: [], now: now) == .future)
    }

    @Test func futureManualCompletedRecordIsStillFuture() {
        let service = Self.service
        let now = Self.noon("2026-08-21")
        let records = [Self.record("2026-08-22", status: .manualCompleted)]

        #expect(service.status(for: "2026-08-22", records: records, now: now) == .future)
    }

    @Test func futureGitHubVerifiedRecordIsStillFuture() {
        let service = Self.service
        let now = Self.noon("2026-08-21")
        let records = [Self.record("2026-08-22", status: .githubVerified)]

        #expect(service.status(for: "2026-08-22", records: records, now: now) == .future)
    }

    @Test func todayPendingIsExcludedFromMonthlyCompletionRate() {
        let service = Self.service
        let now = Self.noon("2026-08-21")
        let records = (1...17).map { Self.record(String(format: "2026-08-%02d", $0)) }
        let rate = service.monthlyCompletionRate(containing: now, records: records, now: now)

        #expect(rate.completedDays == 17)
        #expect(rate.eligibleDays == 20)
        #expect(rate.rate == 0.85)
    }

    @Test func todayCompletedIsIncludedInMonthlyCompletionRate() {
        let service = Self.service
        let now = Self.noon("2026-08-21")
        var records = (1...17).map { Self.record(String(format: "2026-08-%02d", $0)) }
        records.append(Self.record("2026-08-21"))

        let rate = service.monthlyCompletionRate(containing: now, records: records, now: now)

        #expect(rate.completedDays == 18)
        #expect(rate.eligibleDays == 21)
        #expect(abs(rate.rate - (18.0 / 21.0)) < 0.0001)
    }

    @Test func futureDatesAreExcludedFromMonthlyCompletionRate() {
        let service = Self.service
        let now = Self.noon("2026-08-02")
        let records = [Self.record("2026-08-01")]
        let rate = service.monthlyCompletionRate(containing: now, records: records, now: now)

        #expect(rate.completedDays == 1)
        #expect(rate.eligibleDays == 1)
        #expect(rate.rate == 1)
    }

    @Test func untrackedDatesAreExcludedFromMonthlyCompletionRate() {
        let service = Self.service
        let now = Self.noon("2026-08-12")
        let trackingStartDate = Self.noon("2026-08-10")
        let records = [Self.record("2026-08-10")]
        let rate = service.monthlyCompletionRate(
            containing: now,
            records: records,
            now: now,
            trackingStartDate: trackingStartDate
        )

        #expect(rate.completedDays == 1)
        #expect(rate.eligibleDays == 2)
        #expect(rate.rate == 0.5)
    }

    @Test func futureCompletedRecordsAreExcludedFromMonthlyCompletionRate() {
        let service = Self.service
        let now = Self.noon("2026-08-02")
        let records = [
            Self.record("2026-08-01"),
            Self.record("2026-08-03", status: .manualCompleted),
            Self.record("2026-08-04", status: .githubVerified)
        ]
        let rate = service.monthlyCompletionRate(containing: now, records: records, now: now)

        #expect(rate.completedDays == 1)
        #expect(rate.eligibleDays == 1)
        #expect(rate.rate == 1)
    }

    @Test func monthDaysExposeDailyStatuses() {
        let service = Self.service
        let now = Self.noon("2026-08-02")
        let records = [Self.record("2026-08-01")]
        let days = service.days(containing: now, records: records, now: now)

        #expect(days.count == 31)
        #expect(days[0].status == .completed)
        #expect(days[1].status == .pending)
        #expect(days[2].status == .future)
    }

    private static var service: HabitCalendarService {
        HabitCalendarService(dateService: DateService(calendar: calendar))
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func record(_ dateKey: String, status: DailyRecordStatus = .githubVerified) -> DailyRecord {
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
