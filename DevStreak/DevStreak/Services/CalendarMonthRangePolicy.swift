//
//  CalendarMonthRangePolicy.swift
//  DevStreak
//
//  Created by Codex on 8/26/26.
//

import Foundation

struct CalendarMonthRangePolicy {
    var dateService: DateService
    var maxLookbackMonths: Int

    init(
        dateService: DateService = DateService(),
        maxLookbackMonths: Int = 36
    ) {
        self.dateService = dateService
        self.maxLookbackMonths = maxLookbackMonths
    }

    func earliestVisibleMonth(
        now: Date,
        records: [DailyRecord],
        isTrackingEnabled: Bool,
        repositoryCreatedAt: Date?
    ) -> Date {
        let currentMonth = dateService.startOfMonth(containing: now) ?? now

        guard isTrackingEnabled else {
            return currentMonth
        }

        let lookbackStart = dateService
            .addingMonths(-maxLookbackMonths, to: currentMonth)
            .flatMap { dateService.startOfMonth(containing: $0) } ?? currentMonth
        let repositoryCreatedMonth = repositoryCreatedAt
            .flatMap { dateService.startOfMonth(containing: $0) }
        let firstCompletedMonth = records
            .filter { $0.status.isCompleted }
            .compactMap { dateService.date(from: $0.dateKey) }
            .min()
            .flatMap { dateService.startOfMonth(containing: $0) }

        guard let trackingStartMonth = repositoryCreatedMonth ?? firstCompletedMonth else {
            return currentMonth
        }

        return dateService.compareMonth(trackingStartMonth, lookbackStart) == .orderedAscending
            ? lookbackStart
            : trackingStartMonth
    }

    func clampedMonth(
        _ month: Date,
        now: Date,
        records: [DailyRecord],
        isTrackingEnabled: Bool,
        repositoryCreatedAt: Date?
    ) -> Date {
        let currentMonth = dateService.startOfMonth(containing: now) ?? now
        let normalizedMonth = dateService.startOfMonth(containing: month) ?? month
        let earliestMonth = earliestVisibleMonth(
            now: now,
            records: records,
            isTrackingEnabled: isTrackingEnabled,
            repositoryCreatedAt: repositoryCreatedAt
        )

        if dateService.compareMonth(normalizedMonth, currentMonth) == .orderedDescending {
            return currentMonth
        }

        if dateService.compareMonth(normalizedMonth, earliestMonth) == .orderedAscending {
            return earliestMonth
        }

        return normalizedMonth
    }
}
