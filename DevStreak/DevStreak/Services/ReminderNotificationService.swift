//
//  ReminderNotificationService.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation
import UserNotifications

enum ReminderAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var canScheduleNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        }
    }
}

struct ScheduledReminderRequest: Equatable {
    let identifier: String
    let title: String
    let body: String
    let dateComponents: DateComponents
}

protocol UserNotificationScheduling {
    func authorizationStatus() async -> ReminderAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: ScheduledReminderRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [ScheduledReminderRequest]
}

struct UserNotificationCenterAdapter: UserNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> ReminderAuthorizationStatus {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func add(_ request: ScheduledReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: request.dateComponents, repeats: false)
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )

        try await center.add(notificationRequest)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingNotificationRequests() async -> [ScheduledReminderRequest] {
        await center.pendingNotificationRequests().compactMap { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
                return nil
            }

            return ScheduledReminderRequest(
                identifier: request.identifier,
                title: request.content.title,
                body: request.content.body,
                dateComponents: trigger.dateComponents
            )
        }
    }
}

struct ReminderNotificationService {
    static let managedIdentifierPrefix = "devstreak.reminder."

    private let scheduler: UserNotificationScheduling
    private let dateService: DateService
    private let horizonDays: Int

    init(
        scheduler: UserNotificationScheduling = UserNotificationCenterAdapter(),
        dateService: DateService = DateService(),
        horizonDays: Int = 14
    ) {
        self.scheduler = scheduler
        self.dateService = dateService
        self.horizonDays = horizonDays
    }

    func authorizationStatus() async -> ReminderAuthorizationStatus {
        await scheduler.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        (try? await scheduler.requestAuthorization()) == true
    }

    func syncRollingSchedule(settings: ReminderSettings, isTodayCompleted: Bool, now: Date = .now) async {
        await removeManagedPendingRequests()

        let status = await scheduler.authorizationStatus()
        guard status.canScheduleNotifications else {
            return
        }

        for request in requests(settings: settings, isTodayCompleted: isTodayCompleted, now: now) {
            try? await scheduler.add(request)
        }
    }

    func cancelTodayReminders(now: Date = .now) async {
        scheduler.removePendingNotificationRequests(withIdentifiers: todayReminderIdentifiers(now: now))
    }

    func todayReminderIdentifiers(now: Date = .now) -> [String] {
        let todayKey = dateService.todayKey(now: now)
        return ReminderSlot.allCases.map { $0.notificationIdentifier(for: todayKey) }
    }

    func requests(settings: ReminderSettings, isTodayCompleted: Bool, now: Date = .now) -> [ScheduledReminderRequest] {
        let todayKey = dateService.todayKey(now: now)
        var requests: [ScheduledReminderRequest] = []

        for dayOffset in 0..<horizonDays {
            guard let dateKey = dateService.addingDays(dayOffset, to: todayKey) else {
                continue
            }

            if dayOffset == 0 && isTodayCompleted {
                continue
            }

            for slot in ReminderSlot.allCases {
                let preference = settings.preference(for: slot)
                guard preference.isEnabled,
                      let scheduledDate = dateService.dateTime(
                        for: dateKey,
                        hour: preference.hour,
                        minute: preference.minute
                      ),
                      let dateComponents = dateService.dateComponents(
                        for: dateKey,
                        hour: preference.hour,
                        minute: preference.minute
                      ) else {
                    continue
                }

                if dayOffset == 0 && scheduledDate <= now {
                    continue
                }

                requests.append(ScheduledReminderRequest(
                    identifier: slot.notificationIdentifier(for: dateKey),
                    title: "DevStreak",
                    body: slot.notificationBody,
                    dateComponents: dateComponents
                ))
            }
        }

        return requests
    }

    private func removeManagedPendingRequests() async {
        let identifiers = await scheduler.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.managedIdentifierPrefix) }

        guard !identifiers.isEmpty else {
            return
        }

        scheduler.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
