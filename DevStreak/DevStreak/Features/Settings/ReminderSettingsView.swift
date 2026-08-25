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
    @State private var savedSettings = ReminderSettings.default
    @State private var authorizationStatus = ReminderAuthorizationStatus.notDetermined

    private var hasPendingChanges: Bool {
        settings != savedSettings
    }

    private var canEditReminders: Bool {
        authorizationStatus.canScheduleNotifications
    }

    var body: some View {
        Form {
            Section {
                PermissionStatusCard(
                    status: authorizationStatus,
                    message: permissionMessage,
                    requestPermission: {
                        Task {
                            await requestPermission()
                        }
                    },
                    openSettings: openAppSettings
                )
            }

            Section {
                if hasPendingChanges {
                    ReminderPendingChangesRow(
                        applyChanges: applyPendingChanges,
                        discardChanges: {
                            settings = savedSettings
                        }
                    )
                }

                reminderRow(slot: .morning)
                reminderRow(slot: .evening)
                reminderRow(slot: .night)
            } header: {
                Text("리마인더")
            } footer: {
                Text(reminderFooterMessage)
            }
            .disabled(!canEditReminders)
        }
        .navigationTitle("알림 설정")
        .font(DesignTokens.Typography.body)
        .task {
            let loadedSettings = store.load()
            settings = loadedSettings
            savedSettings = loadedSettings
            await refreshAuthorizationStatus()
            await syncSchedule()
        }
    }

    private var reminderFooterMessage: String {
        guard canEditReminders else {
            return "알림 권한을 허용하면 리마인더를 설정할 수 있습니다."
        }

        if hasPendingChanges {
            return "적용 전에는 앞으로의 알림 일정이 바뀌지 않습니다."
        }

        return "토글이나 시각을 변경한 뒤 적용할 수 있습니다."
    }

    private var permissionMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            "알림 권한이 아직 결정되지 않았습니다."
        case .denied:
            "알림이 iOS 설정에서 꺼져 있습니다."
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

        return ReminderPreferenceRow(
            slot: slot,
            isEnabled: Binding(
                get: {
                    settings.preference(for: slot).isEnabled
                },
                set: { isEnabled in
                    var updatedPreference = settings.preference(for: slot)
                    updatedPreference.isEnabled = isEnabled
                    updatePreference(updatedPreference, for: slot)
                }
            ),
            selectedDate: Binding(
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
            )
        )
    }

    private func updatePreference(_ preference: ReminderPreference, for slot: ReminderSlot) {
        settings.setPreference(preference, for: slot)
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
            settings: savedSettings,
            isTodayCompleted: isTodayCompleted
        )
    }

    private func applyPendingChanges() {
        savedSettings = settings
        store.save(settings)

        Task {
            await refreshAuthorizationStatus()
            await syncSchedule()
        }
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

private struct PermissionStatusCard: View {
    let status: ReminderAuthorizationStatus
    let message: String
    let requestPermission: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)

                Text("알림 권한")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)
            }

            Text(message)
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            switch status {
            case .notDetermined:
                Button("알림 허용하기", action: requestPermission)
                    .buttonStyle(.bordered)
            case .denied:
                Button("iOS 설정 열기", action: openSettings)
                    .buttonStyle(.bordered)
            case .authorized, .provisional, .ephemeral:
                EmptyView()
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch status {
        case .notDetermined:
            "bell.badge"
        case .denied:
            "bell.slash"
        case .authorized, .provisional, .ephemeral:
            "bell.badge.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .notDetermined:
            DesignTokens.Color.accent
        case .denied:
            DesignTokens.Color.warning
        case .authorized, .provisional, .ephemeral:
            DesignTokens.Color.success
        }
    }
}

private struct ReminderPendingChangesRow: View {
    let applyChanges: () -> Void
    let discardChanges: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text("변경사항 있음")
                    .font(DesignTokens.Typography.subheadline)
            } icon: {
                Image(systemName: "exclamationmark.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DesignTokens.Color.warning)
            }

            Spacer()

            Button("취소", role: .cancel, action: discardChanges)
                .buttonStyle(.borderless)

            Button(action: applyChanges) {
                Label("적용", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}

private struct ReminderPreferenceRow: View {
    let slot: ReminderSlot
    @Binding var isEnabled: Bool
    @Binding var selectedDate: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: slot.iconName)
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(slot.tint)
                .frame(width: 22)

            Text(slot.title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Color.primaryText)

            DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .disabled(!isEnabled)
                .frame(width: 104, alignment: .leading)
                .accessibilityLabel("\(slot.title) 시간")

            Spacer(minLength: 8)

            Toggle(slot.title, isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 6)
        .font(DesignTokens.Typography.body)
    }
}

private extension ReminderSlot {
    var iconName: String {
        switch self {
        case .morning:
            "sun.max"
        case .evening:
            "sunset"
        case .night:
            "moon"
        }
    }

    var tint: Color {
        switch self {
        case .morning:
            DesignTokens.Color.textSecondary
        case .evening:
            DesignTokens.Color.textSecondary
        case .night:
            DesignTokens.Color.textSecondary
        }
    }
}

#Preview {
    NavigationStack {
        ReminderSettingsView(isTodayCompleted: false)
    }
}
