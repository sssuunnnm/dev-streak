//
//  WidgetDisplayStateTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

struct WidgetDisplayStateTests {
    @Test func currentDateSnapshotCanShowCompletedToday() {
        let snapshot = WidgetSnapshot(
            dateKey: "2026-08-22",
            isTodayCompleted: true,
            currentStreak: 4,
            pendingIdeaCount: 1,
            updatedAt: Date()
        )

        let state = WidgetDisplayState.make(snapshot: snapshot, currentDateKey: "2026-08-22")

        #expect(state.isTodayCompleted)
        #expect(state.goalText == "✓ 1 / 1")
        #expect(state.currentStreak == 4)
    }

    @Test func staleSnapshotDoesNotShowTodayCompleted() {
        let snapshot = WidgetSnapshot(
            dateKey: "2026-08-21",
            isTodayCompleted: true,
            currentStreak: 4,
            pendingIdeaCount: 1,
            updatedAt: Date()
        )

        let state = WidgetDisplayState.make(snapshot: snapshot, currentDateKey: "2026-08-22")

        #expect(!state.isTodayCompleted)
        #expect(state.goalText == "0 / 1")
        #expect(state.currentStreak == 4)
    }
}
