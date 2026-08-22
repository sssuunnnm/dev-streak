//
//  WidgetDisplayState.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

struct WidgetDisplayState: Equatable {
    var dateKey: String
    var isTodayCompleted: Bool
    var currentStreak: Int
    var pendingIdeaCount: Int
    var updatedAt: Date

    var goalText: String {
        isTodayCompleted ? "1 / 1" : "0 / 1"
    }

    static func make(snapshot: WidgetSnapshot, currentDateKey: String) -> WidgetDisplayState {
        guard snapshot.dateKey == currentDateKey else {
            return WidgetDisplayState(
                dateKey: currentDateKey,
                isTodayCompleted: false,
                currentStreak: 0,
                pendingIdeaCount: 0,
                updatedAt: snapshot.updatedAt
            )
        }

        return WidgetDisplayState(
            dateKey: currentDateKey,
            isTodayCompleted: snapshot.isTodayCompleted,
            currentStreak: snapshot.currentStreak,
            pendingIdeaCount: snapshot.pendingIdeaCount,
            updatedAt: snapshot.updatedAt
        )
    }
}
