//
//  ReminderSettingsStoreTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

struct ReminderSettingsStoreTests {
    @Test func defaultSettingsUseEnabledReminderSlots() {
        let store = Self.store(name: "defaultSettingsUseEnabledReminderSlots")
        let settings = store.load()

        #expect(settings.morning == ReminderPreference(isEnabled: true, hour: 9, minute: 0))
        #expect(settings.evening == ReminderPreference(isEnabled: true, hour: 18, minute: 0))
        #expect(settings.night == ReminderPreference(isEnabled: true, hour: 22, minute: 0))
    }

    @Test func savesAndLoadsReminderSettings() {
        let store = Self.store(name: "savesAndLoadsReminderSettings")
        let settings = ReminderSettings(
            morning: ReminderPreference(isEnabled: false, hour: 10, minute: 15),
            evening: ReminderPreference(isEnabled: true, hour: 19, minute: 30),
            night: ReminderPreference(isEnabled: true, hour: 23, minute: 45)
        )

        store.save(settings)

        #expect(store.load() == settings)
    }

    private static func store(name: String) -> ReminderSettingsStore {
        let suiteName = "ReminderSettingsStoreTests.\(name)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return ReminderSettingsStore(userDefaults: userDefaults)
    }
}
