//
//  DateServiceTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/21/26.
//

import Foundation
import Testing
@testable import DevStreak

struct DateServiceTests {
    @Test func dateKeyUsesInjectedTimeZone() {
        let instant = Date(timeIntervalSince1970: 1_767_225_000)
        let utcService = DateService(calendar: Self.calendar(timeZoneIdentifier: "UTC"))
        let seoulService = DateService(calendar: Self.calendar(timeZoneIdentifier: "Asia/Seoul"))

        #expect(utcService.dateKey(for: instant) == "2025-12-31")
        #expect(seoulService.dateKey(for: instant) == "2026-01-01")
    }

    @Test func addingDaysUsesCalendarDayBoundaries() {
        let service = DateService(calendar: Self.calendar(timeZoneIdentifier: "America/Los_Angeles"))

        #expect(service.addingDays(1, to: "2026-03-07") == "2026-03-08")
        #expect(service.addingDays(1, to: "2026-03-08") == "2026-03-09")
        #expect(service.addingDays(-1, to: "2026-03-09") == "2026-03-08")
    }

    @Test func invalidDateKeyReturnsNil() {
        let service = DateService(calendar: Self.calendar(timeZoneIdentifier: "UTC"))

        #expect(service.date(from: "not-a-date") == nil)
        #expect(service.addingDays(1, to: "not-a-date") == nil)
    }

    @Test func detectsPreviousCalendarDay() {
        let service = DateService(calendar: Self.calendar(timeZoneIdentifier: "UTC"))

        #expect(service.isPreviousDay("2026-08-20", before: "2026-08-21"))
        #expect(!service.isPreviousDay("2026-08-19", before: "2026-08-21"))
    }

    @Test func createsDateKeysForMonth() {
        let service = DateService(calendar: Self.calendar(timeZoneIdentifier: "Asia/Seoul"))
        let monthDate = Self.noon("2026-08-21", timeZoneIdentifier: "Asia/Seoul")
        let dateKeys = service.monthDateKeys(containing: monthDate)

        #expect(dateKeys.count == 31)
        #expect(dateKeys.first == "2026-08-01")
        #expect(dateKeys.last == "2026-08-31")
    }

    @Test func calculatesLeadingBlankDaysWithSundayFirstCalendar() {
        let service = DateService(calendar: Self.calendar(timeZoneIdentifier: "Asia/Seoul"))
        let monthDate = Self.noon("2026-08-21", timeZoneIdentifier: "Asia/Seoul")

        #expect(service.leadingBlankDayCount(containing: monthDate) == 6)
    }

    @Test func comparesDateKeysAtDayGranularity() {
        let service = DateService(calendar: Self.calendar(timeZoneIdentifier: "UTC"))

        #expect(service.compare("2026-08-20", "2026-08-21") == .orderedAscending)
        #expect(service.compare("2026-08-21", "2026-08-21") == .orderedSame)
        #expect(service.compare("2026-08-22", "2026-08-21") == .orderedDescending)
        #expect(service.compare("invalid", "2026-08-21") == nil)
    }

    private static func calendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func noon(_ dateKey: String, timeZoneIdentifier: String) -> Date {
        let parts = dateKey.split(separator: "-").compactMap { Int(String($0)) }
        let calendar = calendar(timeZoneIdentifier: timeZoneIdentifier)

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
