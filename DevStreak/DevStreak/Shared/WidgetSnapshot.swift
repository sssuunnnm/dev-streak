//
//  WidgetSnapshot.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var dateKey: String
    var isTodayCompleted: Bool
    var currentStreak: Int
    var pendingIdeaCount: Int
    var updatedAt: Date

    static func fallback(dateKey: String = "") -> WidgetSnapshot {
        WidgetSnapshot(
            dateKey: dateKey,
            isTodayCompleted: false,
            currentStreak: 0,
            pendingIdeaCount: 0,
            updatedAt: .distantPast
        )
    }
}
