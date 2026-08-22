//
//  DashboardView.swift
//  DevStreak
//
//  Created by Codex on 8/21/26.
//

import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DailyRecord.dateKey, order: .reverse) private var records: [DailyRecord]
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    private let dateService = DateService()
    private let streakService = StreakService()
    private let reminderSettingsStore = ReminderSettingsStore()
    private let reminderNotificationService = ReminderNotificationService()
    private let widgetSnapshotService = WidgetSnapshotService()
    private let githubVerificationService = GitHubVerificationService()
    private let githubDailyRecordUpdater = GitHubDailyRecordUpdater()

    @State private var saveErrorMessage: String?
    @State private var githubVerificationState: GitHubVerificationViewState = .idle
    @State private var githubVerificationTask: Task<Void, Never>?

    private var now: Date {
        Date()
    }

    private var todayKey: String {
        dateService.todayKey(now: now)
    }

    private var todayRecord: DailyRecord? {
        records.first { $0.dateKey == todayKey }
    }

    private var isTodayCompleted: Bool {
        todayRecord?.status.isCompleted == true
    }

    private var currentStreak: Int {
        streakService.currentStreak(records: records, now: now)
    }

    private var bestStreak: Int {
        streakService.bestStreak(records: records)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(todayKey)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(isTodayCompleted ? "1 / 1" : "0 / 1")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())

                        Text(isTodayCompleted ? "Writing recorded for today." : "No writing activity yet.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: markTodayCompleted) {
                        Label(isTodayCompleted ? "Completed Today" : "Write Today", systemImage: isTodayCompleted ? "checkmark.circle.fill" : "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isTodayCompleted)

                    HStack(spacing: 16) {
                        streakMetric(title: "Current Streak", value: currentStreak)
                        streakMetric(title: "Best Streak", value: bestStreak)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Activity")
                            .font(.headline)

                        if let todayRecord, todayRecord.status == .githubVerified {
                            Text("GitHub writing activity verified today.")
                                .foregroundStyle(.secondary)
                        } else if let todayRecord, todayRecord.status.isCompleted {
                            Text("Manual completion recorded today.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No writing activity yet.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    githubVerificationSection

                    NavigationLink {
                        IdeaInboxView()
                    } label: {
                        Label("Idea Inbox", systemImage: "lightbulb")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    CalendarMonthView(records: records, now: now)

                    if let saveErrorMessage {
                        Text(saveErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("DevStreak")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ReminderSettingsView(isTodayCompleted: isTodayCompleted)
                    } label: {
                        Label("Reminder Settings", systemImage: "bell")
                    }
                }
            }
            .task {
                refreshWidgetSnapshot()
                verifyGitHubActivityIfNeeded()
                await syncReminderSchedule()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                refreshWidgetSnapshot()
                verifyGitHubActivityIfNeeded()

                Task {
                    await syncReminderSchedule()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }

    private var githubVerificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub")
                        .font(.headline)

                    Text(githubVerificationState.message(isTodayCompleted: isTodayCompleted))
                        .font(.subheadline)
                        .foregroundStyle(githubVerificationState.isError ? .red : .secondary)
                }

                Spacer()

                Button(action: verifyGitHubActivity) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .disabled(githubVerificationState == .checking)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func streakMetric(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(value) days")
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func markTodayCompleted() {
        let completionDate = Date()
        let completionDateKey = dateService.todayKey(now: completionDate)
        var snapshotRecords = records

        if let record = records.first(where: { $0.dateKey == completionDateKey }) {
            record.status = .manualCompleted
            record.completedAt = completionDate
        } else {
            let record = DailyRecord(
                dateKey: completionDateKey,
                status: .manualCompleted,
                completedAt: completionDate,
                createdAt: completionDate
            )
            modelContext.insert(record)
            snapshotRecords.append(record)
        }

        do {
            try modelContext.save()
            saveErrorMessage = nil
            refreshWidgetSnapshot(records: snapshotRecords, now: completionDate)

            Task {
                await reminderNotificationService.cancelTodayReminders(now: completionDate)
            }
        } catch {
            saveErrorMessage = "Could not save today's record."
        }
    }

    private func syncReminderSchedule() async {
        await reminderNotificationService.syncRollingSchedule(
            settings: reminderSettingsStore.load(),
            isTodayCompleted: isTodayCompleted,
            now: now
        )
    }

    private func refreshWidgetSnapshot(records snapshotRecords: [DailyRecord]? = nil, now: Date = Date()) {
        widgetSnapshotService.updateSnapshot(
            records: snapshotRecords ?? records,
            ideas: ideas,
            now: now
        )
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "devstreak" else {
            return
        }
    }

    private func verifyGitHubActivityIfNeeded() {
        guard githubVerificationState == .idle else {
            return
        }

        verifyGitHubActivity()
    }

    private func verifyGitHubActivity() {
        guard githubVerificationTask == nil else {
            return
        }

        githubVerificationState = .checking
        let verificationDate = Date()

        githubVerificationTask = Task {
            let result = await githubVerificationService.verify(now: verificationDate)

            await MainActor.run {
                applyGitHubVerificationResult(result, now: verificationDate)
                githubVerificationTask = nil
            }
        }
    }

    private func applyGitHubVerificationResult(
        _ result: Result<GitHubVerificationResult, GitHubVerificationFailure>,
        now verificationDate: Date
    ) {
        switch result {
        case .success(let verificationResult):
            let verificationDateKey = dateService.todayKey(now: verificationDate)

            guard verificationResult.verifiedDateKeys.contains(verificationDateKey) else {
                githubVerificationState = .noActivity
                return
            }

            let update = githubDailyRecordUpdater.applyVerified(
                dateKey: verificationDateKey,
                records: records,
                now: verificationDate
            )

            var snapshotRecords = records

            if case .created(let record) = update {
                modelContext.insert(record)
                snapshotRecords.append(record)
            }

            do {
                if update.requiresSave {
                    try modelContext.save()
                }

                saveErrorMessage = nil
                githubVerificationState = .verified

                if update.shouldRunCompletionSideEffects {
                    refreshWidgetSnapshot(records: snapshotRecords, now: verificationDate)

                    Task {
                        await reminderNotificationService.cancelTodayReminders(now: verificationDate)
                    }
                }
            } catch {
                modelContext.rollback()
                saveErrorMessage = "Could not save GitHub verification."
                githubVerificationState = .unableToCheck
            }
        case .failure(let failure):
            githubVerificationState = .failure(failure)
        }
    }
}

private enum GitHubVerificationViewState: Equatable {
    case idle
    case checking
    case verified
    case noActivity
    case failure(GitHubVerificationFailure)
    case unableToCheck

    var isError: Bool {
        switch self {
        case .failure, .unableToCheck:
            return true
        case .idle, .checking, .verified, .noActivity:
            return false
        }
    }

    func message(isTodayCompleted: Bool) -> String {
        switch self {
        case .idle:
            return isTodayCompleted ? "Writing recorded." : "Ready to check."
        case .checking:
            return "Checking..."
        case .verified:
            return "Verified ✓"
        case .noActivity:
            return isTodayCompleted ? "No GitHub writing activity yet." : "No writing activity yet."
        case .failure(.rateLimited):
            return "Rate limited. Try again later."
        case .failure(.unauthorizedOrForbidden):
            return "Unable to access repository."
        case .failure(.notFound):
            return "Repository not found."
        case .failure(.networkFailure):
            return "Network unavailable. Retry."
        case .failure(.decodingFailure), .failure(.unknown), .unableToCheck:
            return "Unable to check. Retry."
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [DailyRecord.self, Idea.self], inMemory: true)
}
