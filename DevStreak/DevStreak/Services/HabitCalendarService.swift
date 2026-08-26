//
//  HabitCalendarService.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

enum DailyStatus: String, CaseIterable {
    case completed
    case missed
    case pending
    case future
    case untracked
}

struct HabitCalendarDay: Identifiable {
    let dateKey: String
    let dayNumber: Int
    let status: DailyStatus

    var id: String {
        dateKey
    }
}

struct MonthlyCompletionRate {
    let completedDays: Int
    let eligibleDays: Int

    var rate: Double {
        guard eligibleDays > 0 else {
            return 0
        }

        return Double(completedDays) / Double(eligibleDays)
    }
}

struct HabitCalendarService {
    var dateService: DateService

    init(dateService: DateService = DateService()) {
        self.dateService = dateService
    }

    func days(
        containing date: Date,
        records: [DailyRecord],
        now: Date = .now,
        trackingStartDate: Date? = nil
    ) -> [HabitCalendarDay] {
        dateService.monthDateKeys(containing: date).compactMap { dateKey in
            guard let dayNumber = dateService.dayNumber(for: dateKey) else {
                return nil
            }

            return HabitCalendarDay(
                dateKey: dateKey,
                dayNumber: dayNumber,
                status: status(
                    for: dateKey,
                    records: records,
                    now: now,
                    trackingStartDate: trackingStartDate
                )
            )
        }
    }

    func status(
        for dateKey: String,
        records: [DailyRecord],
        now: Date = .now,
        trackingStartDate: Date? = nil
    ) -> DailyStatus {
        if let trackingStartDate {
            let trackingStartKey = dateService.dateKey(for: trackingStartDate)
            if dateService.compare(dateKey, trackingStartKey) == .orderedAscending {
                return .untracked
            }
        }

        let todayKey = dateService.todayKey(now: now)
        switch dateService.compare(dateKey, todayKey) {
        case .orderedAscending:
            let completedDateKeys = Set(records.filter { $0.status.isCompleted }.map(\.dateKey))
            return completedDateKeys.contains(dateKey) ? .completed : .missed
        case .orderedDescending:
            return .future
        case .orderedSame:
            let completedDateKeys = Set(records.filter { $0.status.isCompleted }.map(\.dateKey))
            return completedDateKeys.contains(dateKey) ? .completed : .pending
        case nil:
            return .future
        }
    }

    func monthlyCompletionRate(
        containing date: Date,
        records: [DailyRecord],
        now: Date = .now,
        trackingStartDate: Date? = nil
    ) -> MonthlyCompletionRate {
        let monthDays = days(
            containing: date,
            records: records,
            now: now,
            trackingStartDate: trackingStartDate
        )

        let completedDays = monthDays.filter { $0.status == .completed }.count
        let eligibleDays = monthDays.filter { $0.status == .completed || $0.status == .missed }.count

        return MonthlyCompletionRate(completedDays: completedDays, eligibleDays: eligibleDays)
    }
}
