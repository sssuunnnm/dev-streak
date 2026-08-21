//
//  ReminderSlot.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

enum ReminderSlot: String, CaseIterable, Identifiable, Codable {
    case morning
    case evening
    case night

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .morning:
            "Morning"
        case .evening:
            "Evening"
        case .night:
            "Night"
        }
    }

    var defaultHour: Int {
        switch self {
        case .morning:
            9
        case .evening:
            18
        case .night:
            22
        }
    }

    var defaultMinute: Int {
        0
    }

    var notificationBody: String {
        switch self {
        case .morning:
            "오늘 하나 기록해볼까요?"
        case .evening:
            "오늘 아직 기록이 없어요. 짧게라도 하나 남겨볼까요?"
        case .night:
            "오늘의 기록이 아직 없어요. Streak가 끊기기 전에 하나 남겨보세요."
        }
    }

    func notificationIdentifier(for dateKey: String) -> String {
        "devstreak.reminder.\(rawValue).\(dateKey)"
    }
}
