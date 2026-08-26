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
    private let githubCredentialStore = GitHubCredentialStore()
    private let githubVerificationService = GitHubVerificationService()
    private let githubDailyRecordUpdater = GitHubDailyRecordUpdater()
    private let githubAutoRefreshPolicy = GitHubVerificationAutoRefreshPolicy()

    @State private var saveErrorMessage: String?
    @State private var githubVerificationState: GitHubVerificationViewState = .idle
    @State private var githubVerificationTask: Task<Void, Never>?
    @State private var lastGitHubAutomaticVerificationAt: Date?
    @State private var manualCompletionConfirmation = ManualCompletionConfirmationState()
    @State private var isGitHubConnectionSettingsPresented = false

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

    private var isTodayGitHubVerified: Bool {
        todayRecord?.status == .githubVerified
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
                        writeAction: {
                            manualCompletionConfirmation.request()
                        },
                        refreshAction: verifyGitHubActivity,
                        connectionAction: {
                            isGitHubConnectionSettingsPresented = true
                        }
                    )

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
                refreshGitHubConnectionState()
                refreshCachedGitHubVerificationState()
                verifyGitHubActivityIfNeeded(now: Date())
                await syncReminderSchedule()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                refreshWidgetSnapshot()
                refreshGitHubConnectionState()
                refreshCachedGitHubVerificationState()
                verifyGitHubActivityIfNeeded(now: Date())

                Task {
                    await syncReminderSchedule()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(
                isPresented: $isGitHubConnectionSettingsPresented,
                onDismiss: {
                    refreshGitHubConnectionState()
                    refreshCachedGitHubVerificationState()
                    verifyGitHubActivityIfNeeded(now: Date())
                }
            ) {
                NavigationStack {
                    GitHubConnectionSettingsView()
                }
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
                Text("오늘 GitHub 기록을 남겼다면 완료로 표시할 수 있습니다.")
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
            return "오늘 기록 완료"
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
        switch githubTokenAvailability() {
        case .available:
            break
        case .missing:
            githubVerificationState = .needsConnection
            return
        case .unavailable:
            githubVerificationState = .failure(.credentialUnavailable)
            return
        }

        guard githubAutoRefreshPolicy.shouldRunAutomaticVerification(
            now: now,
            lastAutomaticVerificationAt: lastGitHubAutomaticVerificationAt,
            isTaskRunning: githubVerificationTask != nil,
            isTodayAlreadyGitHubVerified: isTodayGitHubVerified
        ) else {
            return
        }

        lastGitHubAutomaticVerificationAt = now
        verifyGitHubActivity(now: now)
    }

    private func verifyGitHubActivity() {
        switch githubTokenAvailability() {
        case .available:
            verifyGitHubActivity(now: Date())
        case .missing:
            githubVerificationState = .needsConnection
            isGitHubConnectionSettingsPresented = true
        case .unavailable:
            githubVerificationState = .failure(.credentialUnavailable)
        }
    }

    private func refreshCachedGitHubVerificationState() {
        guard isTodayGitHubVerified else {
            return
        }

        githubVerificationState = .verified(includesToday: true)
    }

    private func refreshGitHubConnectionState() {
        guard !isTodayGitHubVerified else {
            return
        }

        switch githubTokenAvailability() {
        case .available:
            if githubVerificationState == .needsConnection {
                githubVerificationState = .idle
            }
        case .missing:
            githubVerificationState = .needsConnection
        case .unavailable:
            githubVerificationState = .failure(.credentialUnavailable)
        }
    }

    private func githubTokenAvailability() -> GitHubTokenAvailability {
        do {
            return try githubCredentialStore.hasToken() ? .available : .missing
        } catch {
            return .unavailable
        }
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
                githubVerificationState = .verified(includesToday: verificationResult.verifiedDateKeys.contains(verificationDateKey))

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

                Text("GitHub 기록을 꾸준히 쌓는 공간")
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

private struct PrimaryGoalCard: View {
    let dateKey: String
    let isCompleted: Bool
    let currentStreak: Int
    let bestStreak: Int
    let completionSource: String
    let verificationState: GitHubVerificationViewState
    let writeAction: () -> Void
    let refreshAction: () -> Void
    let connectionAction: () -> Void

    init(
        dateKey: String,
        isCompleted: Bool,
        currentStreak: Int,
        bestStreak: Int,
        completionSource: String,
        verificationState: GitHubVerificationViewState,
        writeAction: @escaping () -> Void,
        refreshAction: @escaping () -> Void,
        connectionAction: @escaping () -> Void
    ) {
        self.dateKey = dateKey
        self.isCompleted = isCompleted
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.completionSource = completionSource
        self.verificationState = verificationState
        self.writeAction = writeAction
        self.refreshAction = refreshAction
        self.connectionAction = connectionAction
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
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
                refreshAction: refreshAction,
                connectionAction: connectionAction
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

private struct GitHubVerificationRow: View {
    let state: GitHubVerificationViewState
    let isTodayCompleted: Bool
    let refreshAction: () -> Void
    let connectionAction: () -> Void

    @State private var isHelpPresented = false

    init(
        state: GitHubVerificationViewState,
        isTodayCompleted: Bool,
        refreshAction: @escaping () -> Void,
        connectionAction: @escaping () -> Void
    ) {
        self.state = state
        self.isTodayCompleted = isTodayCompleted
        self.refreshAction = refreshAction
        self.connectionAction = connectionAction
    }

    var body: some View {
        if state == .needsConnection {
            GitHubConnectionRequiredCard(
                connectAction: connectionAction,
                helpAction: {
                    isHelpPresented = true
                }
            )
            .sheet(isPresented: $isHelpPresented) {
                NavigationStack {
                    GitHubVerificationHelpView()
                }
            }
        } else {
            compactStatusRow
        }
    }

    private var compactStatusRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Text(state.message(isTodayCompleted: isTodayCompleted))
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                if let symbolName = state.statusSymbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 10, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(state.tint)
                        .verificationStatusSymbolEffect(isChecking: state == .checking)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: state == .needsConnection ? connectionAction : refreshAction) {
                    Image(systemName: state == .needsConnection ? "link.circle" : "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Color.accent)
                .contentShape(Rectangle())
                .scaleEffect(state == .checking ? 0.96 : 1)
                .disabled(state == .checking)
                .accessibilityLabel(state == .needsConnection ? "GitHub 연결 설정" : "GitHub 기록 새로고침")

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
            }
        }
    }
}

private struct GitHubConnectionRequiredCard: View {
    let connectAction: () -> Void
    let helpAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DesignTokens.Color.accent)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text("GitHub 연결이 필요합니다")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Color.primaryText)

                    Text("커밋 기반 기록 확인을 사용하려면 읽기 권한 토큰을 연결해 주세요.")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: helpAction) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .accessibilityLabel("GitHub 연결 도움말")
            }

            Button(action: connectAction) {
                Label("GitHub 연결하기", systemImage: "key")
            }
            .buttonStyle(TactileButtonStyle(tint: DesignTokens.Color.accent))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.Color.hairline.opacity(0.55), lineWidth: 0.5)
                }
        }
    }
}

private extension View {
    @ViewBuilder
    func verificationStatusSymbolEffect(isChecking: Bool) -> some View {
        if #available(iOS 18.0, *) {
            symbolEffect(.rotate, options: .repeating, value: isChecking)
        } else {
            self
        }
    }
}

private struct IdeaInboxSummaryCard: View {
    let waitingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 16, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DesignTokens.Color.accent.opacity(0.72))
                    .frame(width: 20)

                Text("아이디어 메모")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.captionStrong)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }

            Text("\(waitingCount)개 대기 중")
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .monospacedDigit()
                .padding(.leading, 32)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignTokens.Color.surface.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.Color.hairline.opacity(0.35), lineWidth: 0.5)
                }
        }
    }
}

private enum GitHubVerificationViewState: Equatable {
    case idle
    case needsConnection
    case checking
    case verified(includesToday: Bool)
    case noActivity
    case failure(GitHubVerificationFailure)
    case unableToCheck

    var isError: Bool {
        switch self {
        case .failure, .unableToCheck:
            return true
        case .idle, .needsConnection, .checking, .verified, .noActivity:
            return false
        }
    }

    var statusSymbolName: String? {
        switch self {
        case .idle, .noActivity:
            return nil
        case .needsConnection:
            return "link.circle"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .verified:
            return "checkmark.circle.fill"
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
        case .needsConnection, .checking:
            return DesignTokens.Color.accent
        case .idle, .noActivity:
            return DesignTokens.Color.textSecondary
        }
    }

    func message(isTodayCompleted: Bool) -> String {
        switch self {
        case .idle:
            return isTodayCompleted ? "오늘 기록 완료" : "GitHub 확인 준비됨"
        case .needsConnection:
            return "GitHub 연결이 필요합니다"
        case .checking:
            return "GitHub 기록 확인 중..."
        case .verified(let includesToday):
            return includesToday ? "오늘 GitHub 기록 확인됨" : "최근 GitHub 기록 확인됨"
        case .noActivity:
            return "확인된 GitHub 기록 없음"
        case .failure(.rateLimited(let diagnostics)):
            if let resetAt = diagnostics?.resetAt {
                return "\(resetAt.formatted(date: .omitted, time: .shortened)) 이후 다시 확인해 주세요"
            }

            return "잠시 후 다시 확인해 주세요"
        case .failure(.unauthorizedOrForbidden):
            return "저장소에 접근할 수 없습니다"
        case .failure(.credentialUnavailable):
            return "저장된 GitHub 인증 정보를 불러오지 못했습니다"
        case .failure(.notFound):
            return "저장소를 찾을 수 없습니다"
        case .failure(.networkFailure):
            return "네트워크를 확인해 주세요"
        case .failure(.decodingFailure), .failure(.unknown), .unableToCheck:
            return "GitHub 기록을 확인하지 못했습니다"
        case .failure(.budgetExceeded):
            return "GitHub 기록이 많아 확인을 완료하지 못했습니다"
        }
    }
}

private enum GitHubTokenAvailability {
    case available
    case missing
    case unavailable
}

#Preview {
    DashboardView()
        .modelContainer(for: [DailyRecord.self, Idea.self], inMemory: true)
}
