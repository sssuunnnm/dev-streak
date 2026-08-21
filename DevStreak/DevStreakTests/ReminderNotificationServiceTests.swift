//
//  ReminderNotificationServiceTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

@MainActor
struct ReminderNotificationServiceTests {
    @Test func schedulesFourteenDayHorizonWithMaximumFortyTwoRequests() async {
        let scheduler = FakeUserNotificationScheduler(status: .authorized)
        let service = Self.service(scheduler: scheduler)

        await service.syncRollingSchedule(settings: .default, isTodayCompleted: false, now: Self.date("2026-08-22", hour: 8))

        #expect(scheduler.addedRequests.count == 42)
        #expect(scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.morning.2026-08-22" })
        #expect(scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.night.2026-09-04" })
    }

    @Test func doesNotScheduleRequestsAfterFourteenDayHorizon() async {
        let scheduler = FakeUserNotificationScheduler(status: .authorized)
        let service = Self.service(scheduler: scheduler)

        await service.syncRollingSchedule(settings: .default, isTodayCompleted: false, now: Self.date("2026-08-22", hour: 8))

        #expect(!scheduler.addedRequests.contains { $0.identifier.contains("2026-09-05") })
    }

    @Test func skipsPastReminderTimesForToday() async {
        let scheduler = FakeUserNotificationScheduler(status: .authorized)
        let service = Self.service(scheduler: scheduler)

        await service.syncRollingSchedule(settings: .default, isTodayCompleted: false, now: Self.date("2026-08-22", hour: 19))

        #expect(scheduler.addedRequests.count == 40)
        #expect(!scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.morning.2026-08-22" })
        #expect(!scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.evening.2026-08-22" })
        #expect(scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.night.2026-08-22" })
    }

    @Test func schedulesFutureDatesNormally() async {
        let scheduler = FakeUserNotificationScheduler(status: .authorized)
        let service = Self.service(scheduler: scheduler)

        await service.syncRollingSchedule(settings: .default, isTodayCompleted: false, now: Self.date("2026-08-22", hour: 23))

        #expect(!scheduler.addedRequests.contains { $0.identifier.contains("2026-08-22") })
        #expect(scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.morning.2026-08-23" })
        #expect(scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.evening.2026-08-23" })
        #expect(scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.night.2026-08-23" })
    }

    @Test func todayCompletedExcludesTodayAndKeepsFutureReminders() async {
        let scheduler = FakeUserNotificationScheduler(status: .authorized)
        let service = Self.service(scheduler: scheduler)

        await service.syncRollingSchedule(settings: .default, isTodayCompleted: true, now: Self.date("2026-08-22", hour: 8))

        #expect(scheduler.addedRequests.count == 39)
        #expect(!scheduler.addedRequests.contains { $0.identifier.contains("2026-08-22") })
        #expect(scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.morning.2026-08-23" })
    }

    @Test func completingTodayCancelsOnlyTodayRequests() async {
        let scheduler = FakeUserNotificationScheduler(status: .authorized)
        scheduler.pendingRequests = [
            Self.request("devstreak.reminder.morning.2026-08-22"),
            Self.request("devstreak.reminder.evening.2026-08-22"),
            Self.request("devstreak.reminder.night.2026-08-22"),
            Self.request("devstreak.reminder.morning.2026-08-23"),
            Self.request("devstreak.reminder.evening.2026-08-23"),
            Self.request("devstreak.reminder.night.2026-08-23")
        ]
        let service = Self.service(scheduler: scheduler)

        await service.cancelTodayReminders(now: Self.date("2026-08-22", hour: 12))

        #expect(scheduler.removedIdentifiers == [
            "devstreak.reminder.morning.2026-08-22",
            "devstreak.reminder.evening.2026-08-22",
            "devstreak.reminder.night.2026-08-22"
        ])
        #expect(scheduler.pendingRequests.count == 3)
        #expect(scheduler.pendingRequests.allSatisfy { $0.identifier.contains("2026-08-23") })
    }

    @Test func deniedAuthorizationDoesNotAddRequests() async {
        let scheduler = FakeUserNotificationScheduler(status: .denied)
        let service = Self.service(scheduler: scheduler)

        await service.syncRollingSchedule(settings: .default, isTodayCompleted: false, now: Self.date("2026-08-22", hour: 8))

        #expect(scheduler.addedRequests.isEmpty)
    }

    @Test func notDeterminedDoesNotRequestPermissionAutomatically() async {
        let scheduler = FakeUserNotificationScheduler(status: .notDetermined)
        let service = Self.service(scheduler: scheduler)

        await service.syncRollingSchedule(settings: .default, isTodayCompleted: false, now: Self.date("2026-08-22", hour: 8))

        #expect(scheduler.requestAuthorizationCallCount == 0)
        #expect(scheduler.addedRequests.isEmpty)
    }

    @Test func preferenceEnabledAndAuthorizationRemainIndependent() async {
        let userDefaults = UserDefaults(suiteName: "ReminderNotificationServiceTests.independent")!
        userDefaults.removePersistentDomain(forName: "ReminderNotificationServiceTests.independent")
        let store = ReminderSettingsStore(userDefaults: userDefaults)
        let scheduler = FakeUserNotificationScheduler(status: .denied)
        let service = Self.service(scheduler: scheduler)

        store.save(.default)
        let loadedSettings = store.load()
        await service.syncRollingSchedule(settings: loadedSettings, isTodayCompleted: false, now: Self.date("2026-08-22", hour: 8))

        #expect(loadedSettings.morning.isEnabled)
        #expect(scheduler.addedRequests.isEmpty)
    }

    @Test func timezoneBoundaryUsesLocalDateKeyInIdentifier() async {
        let scheduler = FakeUserNotificationScheduler(status: .authorized)
        let service = Self.service(scheduler: scheduler)
        let now = Self.date("2026-08-22", hour: 0, minute: 30)

        await service.syncRollingSchedule(settings: .default, isTodayCompleted: false, now: now)

        #expect(scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.morning.2026-08-22" })
        #expect(!scheduler.addedRequests.contains { $0.identifier == "devstreak.reminder.morning.2026-08-21" })
    }

    private static func service(scheduler: FakeUserNotificationScheduler) -> ReminderNotificationService {
        ReminderNotificationService(
            scheduler: scheduler,
            dateService: DateService(calendar: calendar),
            horizonDays: 14
        )
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(_ dateKey: String, hour: Int, minute: Int = 0) -> Date {
        let parts = dateKey.split(separator: "-").compactMap { Int(String($0)) }
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: hour,
            minute: minute
        ))!
    }

    private static func request(_ identifier: String) -> ScheduledReminderRequest {
        ScheduledReminderRequest(
            identifier: identifier,
            title: "DevStreak",
            body: "",
            dateComponents: DateComponents()
        )
    }
}

@MainActor
private final class FakeUserNotificationScheduler: UserNotificationScheduling {
    var status: ReminderAuthorizationStatus
    var pendingRequests: [ScheduledReminderRequest]
    var addedRequests: [ScheduledReminderRequest] = []
    var removedIdentifiers: [String] = []
    var requestAuthorizationCallCount = 0

    init(status: ReminderAuthorizationStatus, pendingRequests: [ScheduledReminderRequest] = []) {
        self.status = status
        self.pendingRequests = pendingRequests
    }

    func authorizationStatus() async -> ReminderAuthorizationStatus {
        status
    }

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCallCount += 1
        status = .authorized
        return true
    }

    func add(_ request: ScheduledReminderRequest) async throws {
        addedRequests.append(request)
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func pendingNotificationRequests() async -> [ScheduledReminderRequest] {
        pendingRequests
    }
}
