//
//  WidgetSnapshotService.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation
import WidgetKit

struct WidgetSnapshotService {
    private let dateService: DateService
    private let streakService: StreakService
    private let store: WidgetSnapshotStore

    init(
        dateService: DateService = DateService(),
        streakService: StreakService = StreakService(),
        store: WidgetSnapshotStore = WidgetSnapshotStore()
    ) {
        self.dateService = dateService
        self.streakService = streakService
        self.store = store
    }

    func makeSnapshot(records: [DailyRecord], ideas: [Idea], now: Date = .now) -> WidgetSnapshot {
        let todayKey = dateService.todayKey(now: now)
        let todayRecord = records.first { $0.dateKey == todayKey }

        return WidgetSnapshot(
            dateKey: todayKey,
            isTodayCompleted: todayRecord?.status.isCompleted == true,
            currentStreak: streakService.currentStreak(records: records, now: now),
            pendingIdeaCount: ideas.filter { $0.status == .inbox }.count,
            recentDays: recentDays(records: records, todayKey: todayKey),
            updatedAt: now
        )
    }

    @discardableResult
    func updateSnapshot(records: [DailyRecord], ideas: [Idea], now: Date = .now) -> Bool {
        let snapshot = makeSnapshot(records: records, ideas: ideas, now: now)
        let didSave = store.save(snapshot)

        if didSave {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.widgetKind)
        }

        return didSave
    }

    private func recentDays(records: [DailyRecord], todayKey: String) -> [WidgetRecentDay] {
        let completedDateKeys = Set(records.filter { $0.status.isCompleted }.map(\.dateKey))

        return (-6...0).compactMap { offset in
            guard let dateKey = dateService.addingDays(offset, to: todayKey),
                  let dayNumber = dateService.dayNumber(for: dateKey) else {
                return nil
            }

            return WidgetRecentDay(
                dateKey: dateKey,
                dayNumber: dayNumber,
                isCompleted: completedDateKeys.contains(dateKey),
                isToday: dateKey == todayKey
            )
        }
    }
}
