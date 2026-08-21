//
//  ReminderSettingsView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI
import UIKit

struct ReminderSettingsView: View {
    let isTodayCompleted: Bool

    private let store = ReminderSettingsStore()
    private let notificationService = ReminderNotificationService()

    @State private var settings = ReminderSettings.default
    @State private var authorizationStatus = ReminderAuthorizationStatus.notDetermined

    var body: some View {
        Form {
            Section("Notification Permission") {
                Text(permissionMessage)
                    .foregroundStyle(.secondary)

                switch authorizationStatus {
                case .notDetermined:
                    Button("알림 허용하기") {
                        Task {
                            await requestPermission()
                        }
                    }
                case .denied:
                    Button("iOS Settings 열기") {
                        openAppSettings()
                    }
                case .authorized, .provisional, .ephemeral:
                    EmptyView()
                }
            }

            Section("Reminders") {
                reminderRow(slot: .morning)
                reminderRow(slot: .evening)
                reminderRow(slot: .night)
            }
        }
        .navigationTitle("Reminder Settings")
        .task {
            settings = store.load()
            await refreshAuthorizationStatus()
            await syncSchedule()
        }
    }

    private var permissionMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            "알림 권한이 아직 결정되지 않았습니다."
        case .denied:
            "알림이 iOS Settings에서 비활성화되어 있습니다."
        case .authorized:
            "알림이 활성화되어 있습니다."
        case .provisional:
            "알림이 임시 허용 상태입니다."
        case .ephemeral:
            "알림이 임시 세션에서 허용되어 있습니다."
        }
    }

    private func reminderRow(slot: ReminderSlot) -> some View {
        let preference = settings.preference(for: slot)

        return VStack(alignment: .leading, spacing: 8) {
            Toggle(slot.title, isOn: Binding(
                get: {
                    settings.preference(for: slot).isEnabled
                },
                set: { isEnabled in
                    var updatedPreference = settings.preference(for: slot)
                    updatedPreference.isEnabled = isEnabled
                    updatePreference(updatedPreference, for: slot)
                }
            ))

            DatePicker("Time", selection: Binding(
                get: {
                    date(for: preference)
                },
                set: { date in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                    var updatedPreference = settings.preference(for: slot)
                    updatedPreference.hour = components.hour ?? slot.defaultHour
                    updatedPreference.minute = components.minute ?? slot.defaultMinute
                    updatePreference(updatedPreference, for: slot)
                }
            ), displayedComponents: .hourAndMinute)
            .disabled(!settings.preference(for: slot).isEnabled)
        }
    }

    private func updatePreference(_ preference: ReminderPreference, for slot: ReminderSlot) {
        settings.setPreference(preference, for: slot)
        store.save(settings)

        Task {
            await refreshAuthorizationStatus()
            await syncSchedule()
        }
    }

    private func requestPermission() async {
        _ = await notificationService.requestAuthorization()
        await refreshAuthorizationStatus()
        await syncSchedule()
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await notificationService.authorizationStatus()
    }

    private func syncSchedule() async {
        await notificationService.syncRollingSchedule(
            settings: settings,
            isTodayCompleted: isTodayCompleted
        )
    }

    private func date(for preference: ReminderPreference) -> Date {
        Calendar.current.date(from: DateComponents(
            hour: preference.hour,
            minute: preference.minute
        )) ?? Date()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView(isTodayCompleted: false)
    }
}
