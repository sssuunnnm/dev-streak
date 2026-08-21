//
//  ReminderSettings.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

struct ReminderPreference: Codable, Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    init(isEnabled: Bool, hour: Int, minute: Int) {
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
    }

    init(slot: ReminderSlot) {
        self.init(isEnabled: true, hour: slot.defaultHour, minute: slot.defaultMinute)
    }
}

struct ReminderSettings: Codable, Equatable {
    var morning: ReminderPreference
    var evening: ReminderPreference
    var night: ReminderPreference

    static let `default` = ReminderSettings(
        morning: ReminderPreference(slot: .morning),
        evening: ReminderPreference(slot: .evening),
        night: ReminderPreference(slot: .night)
    )

    func preference(for slot: ReminderSlot) -> ReminderPreference {
        switch slot {
        case .morning:
            morning
        case .evening:
            evening
        case .night:
            night
        }
    }

    mutating func setPreference(_ preference: ReminderPreference, for slot: ReminderSlot) {
        switch slot {
        case .morning:
            morning = preference
        case .evening:
            evening = preference
        case .night:
            night = preference
        }
    }
}
