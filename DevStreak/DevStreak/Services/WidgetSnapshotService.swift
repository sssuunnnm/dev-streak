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
}
