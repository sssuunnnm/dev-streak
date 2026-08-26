//
//  WidgetSnapshotServiceTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

@MainActor
struct WidgetSnapshotServiceTests {
    @Test func snapshotReflectsTodayCompletionAndCurrentStreak() {
        let service = Self.service
        let records = [
            Self.record("2026-08-20"),
            Self.record("2026-08-21"),
            Self.record("2026-08-22")
        ]

        let snapshot = service.makeSnapshot(records: records, ideas: [], now: Self.noon("2026-08-22"))

        #expect(snapshot.dateKey == "2026-08-22")
        #expect(snapshot.isTodayCompleted)
        #expect(snapshot.currentStreak == 3)
    }

    @Test func snapshotCountsOnlyInboxIdeas() {
        let ideas = [
            Idea(title: "Inbox 1", status: .inbox),
            Idea(title: "Inbox 2", status: .inbox),
            Idea(title: "Used", status: .used),
            Idea(title: "Archived", status: .archived)
        ]

        let snapshot = Self.service.makeSnapshot(records: [], ideas: ideas, now: Self.noon("2026-08-22"))

        #expect(snapshot.pendingIdeaCount == 2)
    }

    @Test func snapshotIncludesRecentSevenDays() {
        let records = [
            Self.record("2026-08-16"),
            Self.record("2026-08-18"),
            Self.record("2026-08-22")
        ]

        let snapshot = Self.service.makeSnapshot(records: records, ideas: [], now: Self.noon("2026-08-22"))

        #expect(snapshot.recentDays.map(\.dateKey) == [
            "2026-08-16",
            "2026-08-17",
            "2026-08-18",
            "2026-08-19",
            "2026-08-20",
            "2026-08-21",
            "2026-08-22"
        ])
        #expect(snapshot.recentDays.map(\.dayNumber) == [16, 17, 18, 19, 20, 21, 22])
        #expect(snapshot.recentDays.map(\.isCompleted) == [true, false, true, false, false, false, true])
        #expect(snapshot.recentDays.map(\.isToday) == [false, false, false, false, false, false, true])
    }

    private static var service: WidgetSnapshotService {
        WidgetSnapshotService(
            dateService: DateService(calendar: calendar),
            streakService: StreakService(dateService: DateService(calendar: calendar)),
            store: WidgetSnapshotStore(defaults: nil)
        )
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
