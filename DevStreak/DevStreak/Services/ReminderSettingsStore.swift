//
//  ReminderSettingsStore.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

struct ReminderSettingsStore {
    private let userDefaults: UserDefaults
    private let key = "reminderSettings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> ReminderSettings {
        guard let data = userDefaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) else {
            return .default
        }

        return settings
    }

    func save(_ settings: ReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }

    func reset() {
        userDefaults.removeObject(forKey: key)
    }
}
