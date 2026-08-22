//
//  WidgetSnapshotStoreTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

struct WidgetSnapshotStoreTests {
    @Test func saveAndLoadSnapshot() {
        let defaults = Self.defaults()
        let store = WidgetSnapshotStore(defaults: defaults)
        let snapshot = WidgetSnapshot(
            dateKey: "2026-08-22",
            isTodayCompleted: true,
            currentStreak: 7,
            pendingIdeaCount: 2,
            updatedAt: Date(timeIntervalSince1970: 1_787_318_400)
        )

        #expect(store.save(snapshot))
        #expect(store.load() == snapshot)
    }

    @Test func emptyStoreReturnsFallbackSnapshot() {
        let store = WidgetSnapshotStore(defaults: Self.defaults())

        #expect(store.load(fallbackDateKey: "2026-08-22") == .fallback(dateKey: "2026-08-22"))
    }

    @Test func corruptDataReturnsFallbackSnapshot() {
        let defaults = Self.defaults()
        defaults.set(Data("not json".utf8), forKey: "devstreak.widget.snapshot")

        let store = WidgetSnapshotStore(defaults: defaults)

        #expect(store.load(fallbackDateKey: "2026-08-22") == .fallback(dateKey: "2026-08-22"))
    }

    private static func defaults() -> UserDefaults {
        let suiteName = "WidgetSnapshotStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
