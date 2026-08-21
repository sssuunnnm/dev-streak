//
//  StreakService.swift
//  DevStreak
//
//  Created by Codex on 8/21/26.
//

import Foundation

struct StreakService {
    var dateService: DateService

    init(dateService: DateService = DateService()) {
        self.dateService = dateService
    }

    func currentStreak(records: [DailyRecord], now: Date = .now) -> Int {
        let completedKeys = completedDateKeys(from: records)
        let todayKey = dateService.todayKey(now: now)
        let startKey: String

        if completedKeys.contains(todayKey) {
            startKey = todayKey
        } else if let yesterdayKey = dateService.addingDays(-1, to: todayKey) {
            startKey = yesterdayKey
        } else {
            return 0
        }

        var count = 0
        var cursor: String? = startKey

        while let dateKey = cursor, completedKeys.contains(dateKey) {
            count += 1
            cursor = dateService.addingDays(-1, to: dateKey)
        }

        return count
    }

    func bestStreak(records: [DailyRecord]) -> Int {
        let sortedKeys = completedDateKeys(from: records).sorted()
        guard var previousKey = sortedKeys.first else {
            return 0
        }

        var current = 1
        var best = 1

        for dateKey in sortedKeys.dropFirst() {
            if dateService.isPreviousDay(previousKey, before: dateKey) {
                current += 1
            } else {
                current = 1
            }

            best = max(best, current)
            previousKey = dateKey
        }

        return best
    }

    private func completedDateKeys(from records: [DailyRecord]) -> Set<String> {
        Set(records.filter { $0.status.isCompleted }.map(\.dateKey))
    }
}
