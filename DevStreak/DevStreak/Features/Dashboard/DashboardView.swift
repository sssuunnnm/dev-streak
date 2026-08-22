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
    private let githubAutoRefreshPolicy = GitHubVerificationAutoRefreshPolicy()

    @State private var saveErrorMessage: String?
    @State private var githubVerificationState: GitHubVerificationViewState = .idle
    @State private var githubVerificationTask: Task<Void, Never>?
    @State private var lastGitHubAutomaticVerificationAt: Date?
    @State private var manualCompletionConfirmation = ManualCompletionConfirmationState()

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
                    DashboardHeader {
                        ReminderSettingsView(isTodayCompleted: isTodayCompleted)
                    }

                    PrimaryGoalCard(
                        dateKey: todayKey,
                        isCompleted: isTodayCompleted,
                        currentStreak: currentStreak,
                        bestStreak: bestStreak,
                        completionSource: completionSourceText,
                        verificationState: githubVerificationState,
                        gitHubSettingsDestination: {
                            GitHubConnectionSettingsView()
                        },
                        writeAction: {
                            manualCompletionConfirmation.request()
                        },
                        refreshAction: verifyGitHubActivity
                    )

                    Divider()
                        .overlay(DesignTokens.Color.hairline)

                    NavigationLink {
                        IdeaInboxView()
                    } label: {
                        IdeaInboxSummaryCard(waitingCount: inboxIdeaCount)
                    }
                    .buttonStyle(.plain)

                    CalendarMonthView(records: records, now: now)

                    if let saveErrorMessage {
                        Text(saveErrorMessage)
                            .font(DesignTokens.Typography.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(DesignTokens.Spacing.page)
            }
            .font(DesignTokens.Typography.body)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                refreshWidgetSnapshot()
                verifyGitHubActivityIfNeeded(now: Date())
                await syncReminderSchedule()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                refreshWidgetSnapshot()
                verifyGitHubActivityIfNeeded(now: Date())

                Task {
                    await syncReminderSchedule()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .alert("오늘 기록을 완료했나요?", isPresented: manualCompletionBinding) {
                Button("완료로 표시") {
                    manualCompletionConfirmation.confirm {
                        markTodayCompleted()
                    }
                }

                Button("취소", role: .cancel) {
                    manualCompletionConfirmation.cancel()
                }
            } message: {
                Text("기술 블로그에 오늘의 기록을 남겼다면 완료로 표시할 수 있습니다.")
            }
        }
    }

    private var manualCompletionBinding: Binding<Bool> {
        Binding(
            get: {
                manualCompletionConfirmation.isPresented
            },
            set: { isPresented in
                if isPresented {
                    manualCompletionConfirmation.request()
                } else {
                    manualCompletionConfirmation.cancel()
                }
            }
        )
    }

    private var completionSourceText: String {
        if let todayRecord, todayRecord.status == .githubVerified {
            return "GitHub에서 기록 확인"
        } else if let todayRecord, todayRecord.status.isCompleted {
            return "오늘 기록 완료"
        } else {
            return "아직 오늘 기록이 없어요"
        }
    }

    private var inboxIdeaCount: Int {
        ideas.filter { $0.status == .inbox }.count
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
            saveErrorMessage = "오늘 기록을 저장하지 못했습니다."
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

    private func verifyGitHubActivityIfNeeded(now: Date) {
        guard githubAutoRefreshPolicy.shouldRunAutomaticVerification(
            now: now,
            lastAutomaticVerificationAt: lastGitHubAutomaticVerificationAt,
            isTaskRunning: githubVerificationTask != nil
        ) else {
            return
        }

        lastGitHubAutomaticVerificationAt = now
        verifyGitHubActivity(now: now)
    }

    private func verifyGitHubActivity() {
        verifyGitHubActivity(now: Date())
    }

    private func verifyGitHubActivity(now verificationDate: Date) {
        guard githubVerificationTask == nil else {
            return
        }

        githubVerificationState = .checking

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

            guard verificationResult.hasActivity else {
                githubVerificationState = .noActivity
                return
            }

            let updates = githubDailyRecordUpdater.applyVerified(
                dateKeys: verificationResult.verifiedDateKeys,
                records: records,
                now: verificationDate
            )

            var snapshotRecords = records

            for update in updates {
                if case .created(let record) = update {
                    modelContext.insert(record)
                    snapshotRecords.append(record)
                }
            }

            do {
                if updates.contains(where: \.requiresSave) {
                    try modelContext.save()
                }

                saveErrorMessage = nil
                githubVerificationState = .verified

                refreshWidgetSnapshot(records: snapshotRecords, now: verificationDate)

                if verificationResult.verifiedDateKeys.contains(verificationDateKey) {
                    Task {
                        await reminderNotificationService.cancelTodayReminders(now: verificationDate)
                    }
                }
            } catch {
                modelContext.rollback()
                saveErrorMessage = "GitHub 확인 결과를 저장하지 못했습니다."
                githubVerificationState = .unableToCheck
            }
        case .failure(let failure):
            githubVerificationState = .failure(failure)
        }
    }
}

private struct DashboardHeader<ReminderDestination: View>: View {
    let reminderDestination: ReminderDestination

    init(@ViewBuilder reminderDestination: () -> ReminderDestination) {
        self.reminderDestination = reminderDestination()
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DevStreak")
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(DesignTokens.Color.primaryText)

                Text("기술 기록을 꾸준히 쌓는 공간")
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }

            Spacer()

            NavigationLink {
                reminderDestination
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("알림 설정")
        }
    }
}

private struct PrimaryGoalCard<GitHubSettingsDestination: View>: View {
    let dateKey: String
    let isCompleted: Bool
    let currentStreak: Int
    let bestStreak: Int
    let completionSource: String
    let verificationState: GitHubVerificationViewState
    let gitHubSettingsDestination: GitHubSettingsDestination
    let writeAction: () -> Void
    let refreshAction: () -> Void

    init(
        dateKey: String,
        isCompleted: Bool,
        currentStreak: Int,
        bestStreak: Int,
        completionSource: String,
        verificationState: GitHubVerificationViewState,
        @ViewBuilder gitHubSettingsDestination: () -> GitHubSettingsDestination,
        writeAction: @escaping () -> Void,
        refreshAction: @escaping () -> Void
    ) {
        self.dateKey = dateKey
        self.isCompleted = isCompleted
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.completionSource = completionSource
        self.verificationState = verificationState
        self.gitHubSettingsDestination = gitHubSettingsDestination()
        self.writeAction = writeAction
        self.refreshAction = refreshAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.tight) {
                    Text("오늘")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Color.primaryText)

                    Text(dateKey)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
                .layoutPriority(1)

                Spacer()

                StreakInlineMetrics(currentStreak: currentStreak, bestStreak: bestStreak)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(isCompleted ? "1 / 1" : "0 / 1")
                    .font(DesignTokens.Typography.heroMetric)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(isCompleted ? completionSource : "짧게라도 하나 남기면 오늘의 기록이 이어집니다.")
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }

            if !isCompleted {
                Button(action: writeAction) {
                    Label("오늘 기록 완료", systemImage: "checkmark.circle")
                }
                .buttonStyle(TactileButtonStyle(tint: DesignTokens.Color.accent))
            }

            GitHubVerificationRow(
                state: verificationState,
                isTodayCompleted: isCompleted,
                settingsDestination: {
                    gitHubSettingsDestination
                },
                refreshAction: refreshAction
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: isCompleted)
    }
}

private struct StreakInlineMetrics: View {
    let currentStreak: Int
    let bestStreak: Int

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.tight) {
                Text("연속 기록")
                    .font(DesignTokens.Typography.captionStrong)
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                Text("\(currentStreak)일")
                    .font(DesignTokens.Typography.title3)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.Color.primaryText)
            }

            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.tight) {
                Text("최고 기록")
                    .font(DesignTokens.Typography.captionStrong)
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                Text("\(bestStreak)일")
                    .font(DesignTokens.Typography.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }
}

private struct GitHubVerificationRow<SettingsDestination: View>: View {
    let state: GitHubVerificationViewState
    let isTodayCompleted: Bool
    let settingsDestination: SettingsDestination
    let refreshAction: () -> Void

    @State private var isHelpPresented = false

    init(
        state: GitHubVerificationViewState,
        isTodayCompleted: Bool,
        @ViewBuilder settingsDestination: () -> SettingsDestination,
        refreshAction: @escaping () -> Void
    ) {
        self.state = state
        self.isTodayCompleted = isTodayCompleted
        self.settingsDestination = settingsDestination()
        self.refreshAction = refreshAction
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.symbolName)
                .font(.system(size: 16, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(state.tint)
                .frame(width: 22)
                .symbolEffect(.rotate, options: .repeating, value: state == .checking)

            VStack(alignment: .leading, spacing: 2) {
                Text("GitHub 기록 확인")
                    .font(DesignTokens.Typography.captionStrong)
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                Text(state.message(isTodayCompleted: isTodayCompleted))
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }

            Spacer()

            Button {
                isHelpPresented = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .accessibilityLabel("GitHub 기록 확인 도움말")
            .sheet(isPresented: $isHelpPresented) {
                NavigationStack {
                    GitHubVerificationHelpView()
                }
            }

            NavigationLink {
                settingsDestination
            } label: {
                Image(systemName: "key")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .accessibilityLabel("GitHub 연결 설정")

            Button(action: refreshAction) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Color.accent)
            .contentShape(Rectangle())
            .scaleEffect(state == .checking ? 0.96 : 1)
            .disabled(state == .checking)
        }
    }
}

private struct IdeaInboxSummaryCard: View {
    let waitingCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb")
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(DesignTokens.Color.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tight) {
                Text("Idea Inbox")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)

                Text("\(waitingCount)개 대기 중")
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .monospacedDigit()
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(DesignTokens.Typography.captionStrong)
                .foregroundStyle(DesignTokens.Color.textSecondary)
        }
        .padding(.vertical, 4)
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

    var symbolName: String {
        switch self {
        case .idle:
            return "checkmark.seal"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .verified:
            return "checkmark.seal.fill"
        case .noActivity:
            return "smallcircle.filled.circle"
        case .failure, .unableToCheck:
            return "exclamationmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .verified:
            return DesignTokens.Color.success
        case .failure, .unableToCheck:
            return DesignTokens.Color.warning
        case .checking:
            return DesignTokens.Color.accent
        case .idle, .noActivity:
            return DesignTokens.Color.textSecondary
        }
    }

    func message(isTodayCompleted: Bool) -> String {
        switch self {
        case .idle:
            return isTodayCompleted ? "기록 완료" : "확인 준비됨"
        case .checking:
            return "확인 중..."
        case .verified:
            return "확인됨"
        case .noActivity:
            return isTodayCompleted ? "아직 GitHub 기록은 없어요" : "아직 기록이 없어요"
        case .failure(.rateLimited(let diagnostics)):
            if let resetAt = diagnostics?.resetAt {
                return "\(resetAt.formatted(date: .omitted, time: .shortened)) 이후 다시 확인해 주세요"
            }

            return "잠시 후 다시 확인해 주세요"
        case .failure(.unauthorizedOrForbidden):
            return "저장소에 접근할 수 없습니다"
        case .failure(.notFound):
            return "저장소를 찾을 수 없습니다"
        case .failure(.networkFailure):
            return "네트워크를 확인해 주세요"
        case .failure(.decodingFailure), .failure(.unknown), .unableToCheck:
            return "확인하지 못했습니다"
        case .failure(.budgetExceeded):
            return "GitHub 기록이 많아 확인을 완료하지 못했습니다"
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [DailyRecord.self, Idea.self], inMemory: true)
}
