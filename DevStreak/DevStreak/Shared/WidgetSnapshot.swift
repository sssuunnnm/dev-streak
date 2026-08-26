//
//  WidgetSnapshot.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

nonisolated struct WidgetRecentDay: Codable, Equatable, Identifiable {
    var dateKey: String
    var dayNumber: Int
    var isCompleted: Bool
    var isToday: Bool

    var id: String {
        dateKey
    }
}

nonisolated struct WidgetSnapshot: Codable, Equatable {
    var dateKey: String
    var isTodayCompleted: Bool
    var currentStreak: Int
    var pendingIdeaCount: Int
    var recentDays: [WidgetRecentDay]
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case dateKey
        case isTodayCompleted
        case currentStreak
        case pendingIdeaCount
        case recentDays
        case updatedAt
    }

    init(
        dateKey: String,
        isTodayCompleted: Bool,
        currentStreak: Int,
        pendingIdeaCount: Int,
        recentDays: [WidgetRecentDay] = [],
        updatedAt: Date
    ) {
        self.dateKey = dateKey
        self.isTodayCompleted = isTodayCompleted
        self.currentStreak = currentStreak
        self.pendingIdeaCount = pendingIdeaCount
        self.recentDays = recentDays
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        dateKey = try container.decode(String.self, forKey: .dateKey)
        isTodayCompleted = try container.decode(Bool.self, forKey: .isTodayCompleted)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        pendingIdeaCount = try container.decode(Int.self, forKey: .pendingIdeaCount)
        recentDays = try container.decodeIfPresent([WidgetRecentDay].self, forKey: .recentDays) ?? []
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    static func fallback(dateKey: String = "") -> WidgetSnapshot {
        WidgetSnapshot(
            dateKey: dateKey,
            isTodayCompleted: false,
            currentStreak: 0,
            pendingIdeaCount: 0,
            recentDays: [],
            updatedAt: .distantPast
        )
    }
}
