//
//  GitHubConnectionCoordinator.swift
//  DevStreak
//
//  Created by Codex on 8/26/26.
//

import Combine
import SwiftData
import SwiftUI

@MainActor
final class GitHubConnectionCoordinator: ObservableObject {
    @Published private(set) var hasSavedToken = false
    @Published private(set) var connectionState = GitHubConnectionState.idle
    @Published private(set) var backfillState = GitHubBackfillViewState.idle

    private let credentialStore: GitHubCredentialStore
    private let repositoryMetadataStore: GitHubRepositoryMetadataStore
    private let widgetSnapshotService: WidgetSnapshotService
    private let backfillService: GitHubBackfillService
    private let initialBackfillService: GitHubBackfillService
    private let initialBackfillStore: GitHubInitialBackfillStore

    private var backfillTask: Task<Void, Never>?
    private var connectionTestTask: Task<Void, Never>?

    init() {
        self.credentialStore = GitHubCredentialStore()
        self.repositoryMetadataStore = GitHubRepositoryMetadataStore()
        self.widgetSnapshotService = WidgetSnapshotService()
        self.backfillService = GitHubBackfillService()
        self.initialBackfillService = GitHubBackfillService(
            lookbackDays: GitHubVerificationDefaults.initialBackfillLookbackDays,
            authenticatedRequestLimit: GitHubVerificationDefaults.authenticatedInitialBackfillRequestLimit
        )
        self.initialBackfillStore = GitHubInitialBackfillStore()
    }

    init(
        credentialStore: GitHubCredentialStore,
        repositoryMetadataStore: GitHubRepositoryMetadataStore,
        widgetSnapshotService: WidgetSnapshotService,
        backfillService: GitHubBackfillService,
        initialBackfillService: GitHubBackfillService,
        initialBackfillStore: GitHubInitialBackfillStore
    ) {
        self.credentialStore = credentialStore
        self.repositoryMetadataStore = repositoryMetadataStore
        self.widgetSnapshotService = widgetSnapshotService
        self.backfillService = backfillService
        self.initialBackfillService = initialBackfillService
        self.initialBackfillStore = initialBackfillStore
    }

    deinit {
        backfillTask?.cancel()
        connectionTestTask?.cancel()
    }

    func refreshSavedState() {
        do {
            hasSavedToken = try credentialStore.hasToken()
            if !hasSavedToken, connectionState == .idle {
                connectionState = .needsToken
            }
        } catch {
            hasSavedToken = false
            connectionState = .failed(.credentialUnavailable)
        }
    }

    func saveToken(
        _ token: String,
        records: [DailyRecord],
        ideas: [Idea],
        modelContext: ModelContext
    ) {
        do {
            try credentialStore.saveToken(token)
            hasSavedToken = try credentialStore.hasToken()
            connectionState = hasSavedToken ? .saved : .needsToken
            runInitialBackfillIfNeeded(records: records, ideas: ideas, modelContext: modelContext)
        } catch {
            connectionState = .failed(.credentialUnavailable)
        }
    }

    func deleteToken(
        records: [DailyRecord],
        ideas: [Idea],
        modelContext: ModelContext
    ) {
        backfillTask?.cancel()
        backfillTask = nil
        connectionTestTask?.cancel()
        connectionTestTask = nil

        do {
            try credentialStore.deleteToken()
            hasSavedToken = false
            connectionState = .needsToken
            backfillState = .idle
            initialBackfillStore.reset()
            repositoryMetadataStore.reset()

            let remainingRecords = records.filter { $0.status != .githubVerified }
            for record in records where record.status == .githubVerified {
                modelContext.delete(record)
            }

            try modelContext.save()
            widgetSnapshotService.updateSnapshot(records: remainingRecords, ideas: ideas, now: Date())
        } catch {
            connectionState = .failed(.credentialUnavailable)
        }
    }

    func testConnection() {
        connectionTestTask?.cancel()
        connectionState = .testing

        connectionTestTask = Task {
            let service = GitHubConnectionTestService(client: GitHubAPIClient())
            let result = await service.testConnection()

            guard !Task.isCancelled else {
                return
            }

            switch result {
            case .success(let repository):
                repositoryMetadataStore.save(createdAt: repository.createdAt)
                connectionState = .connected
            case .failure(.rateLimited(let diagnostics)):
                connectionState = .rateLimited(diagnostics)
            case .failure(let failure):
                connectionState = .failed(failure)
            }

            refreshSavedState()
            connectionTestTask = nil
        }
    }

    func runManualBackfill(
        records: [DailyRecord],
        ideas: [Idea],
        modelContext: ModelContext
    ) {
        runBackfill(
            service: backfillService,
            markInitialBackfillCompleted: false,
            records: records,
            ideas: ideas,
            modelContext: modelContext
        )
    }

    func runInitialBackfillIfNeeded(
        records: [DailyRecord],
        ideas: [Idea],
        modelContext: ModelContext
    ) {
        guard hasSavedToken,
              !initialBackfillStore.hasCompletedInitialBackfill,
              backfillTask == nil else {
            return
        }

        runBackfill(
            service: initialBackfillService,
            markInitialBackfillCompleted: true,
            records: records,
            ideas: ideas,
            modelContext: modelContext
        )
    }

    private func runBackfill(
        service: GitHubBackfillService,
        markInitialBackfillCompleted: Bool,
        records: [DailyRecord],
        ideas: [Idea],
        modelContext: ModelContext
    ) {
        guard backfillTask == nil else {
            return
        }

        backfillState = .syncing

        backfillTask = Task {
            await refreshRepositoryMetadataIfPossible()

            guard !Task.isCancelled, credentialAvailability() == .available else {
                backfillState = .idle
                backfillTask = nil
                return
            }

            let result = await service.backfill(
                records: records,
                ideas: ideas,
                modelContext: modelContext,
                now: Date()
            )

            guard !Task.isCancelled, credentialAvailability() == .available else {
                backfillState = .idle
                backfillTask = nil
                return
            }

            switch result {
            case .success(let backfillResult):
                if markInitialBackfillCompleted {
                    initialBackfillStore.markCompleted()
                }

                backfillState = backfillResult.changedDayCount > 0
                    ? .completed(changedDayCount: backfillResult.changedDayCount)
                    : .completedWithoutChanges
            case .failure(.cancelled):
                backfillState = .idle
            case .failure(let failure):
                backfillState = .failed(failure)
            }

            refreshSavedState()
            backfillTask = nil
        }
    }

    private func refreshRepositoryMetadataIfPossible() async {
        let service = GitHubConnectionTestService(client: GitHubAPIClient())
        guard case .success(let repository) = await service.testConnection(),
              !Task.isCancelled,
              credentialAvailability() == .available else {
            return
        }

        repositoryMetadataStore.save(createdAt: repository.createdAt)
    }

    private func credentialAvailability() -> GitHubCredentialAvailability {
        do {
            return try credentialStore.hasToken() ? .available : .missing
        } catch {
            return .unavailable
        }
    }
}

private enum GitHubCredentialAvailability {
    case available
    case missing
    case unavailable
}

struct GitHubInitialBackfillStore {
    private let userDefaults: UserDefaults
    private let key = "githubInitialBackfillCompleted"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var hasCompletedInitialBackfill: Bool {
        userDefaults.bool(forKey: key)
    }

    func markCompleted() {
        userDefaults.set(true, forKey: key)
    }

    func reset() {
        userDefaults.removeObject(forKey: key)
    }
}

enum GitHubBackfillViewState: Equatable {
    case idle
    case syncing
    case completed(changedDayCount: Int)
    case completedWithoutChanges
    case failed(GitHubBackfillFailure)

    var message: String? {
        switch self {
        case .idle:
            return nil
        case .syncing:
            return "GitHub 기록 확인 중..."
        case .completed(let changedDayCount):
            return "\(changedDayCount)일의 기록을 동기화했습니다."
        case .completedWithoutChanges:
            return "새로 반영할 기록이 없습니다."
        case .failed(.verification(let failure)):
            return failure.backfillMessage
        case .failed(.saveFailed):
            return "동기화 결과를 저장하지 못했습니다."
        case .failed(.cancelled):
            return nil
        }
    }

    var tint: Color {
        switch self {
        case .completed, .completedWithoutChanges:
            return DesignTokens.Color.success
        case .syncing:
            return DesignTokens.Color.accent
        case .idle:
            return DesignTokens.Color.textSecondary
        case .failed:
            return DesignTokens.Color.warning
        }
    }
}

extension GitHubVerificationFailure {
    var backfillMessage: String {
        switch self {
        case .rateLimited(let diagnostics):
            if let resetAt = diagnostics?.resetAt {
                return "\(resetAt.formatted(date: .omitted, time: .shortened)) 이후 다시 확인해 주세요."
            }

            return "GitHub 요청 한도에 도달했습니다."
        case .unauthorizedOrForbidden:
            return "GitHub 연결을 다시 확인해 주세요."
        case .notFound:
            return "저장소 접근 권한을 확인해 주세요."
        case .credentialUnavailable:
            return "저장된 GitHub 인증 정보를 불러오지 못했습니다."
        case .networkFailure:
            return "네트워크 연결을 확인해 주세요."
        case .budgetExceeded:
            return "GitHub 기록이 많아 최근 기록 동기화를 완료하지 못했습니다."
        case .decodingFailure, .unknown:
            return "동기화를 완료하지 못했습니다."
        }
    }
}

enum GitHubConnectionState: Equatable {
    case idle
    case needsToken
    case saved
    case testing
    case connected
    case rateLimited(GitHubRateLimitDiagnostics?)
    case failed(GitHubConnectionFailure)

    var tint: Color {
        switch self {
        case .connected, .saved:
            return DesignTokens.Color.success
        case .rateLimited:
            return DesignTokens.Color.warning
        case .testing:
            return DesignTokens.Color.accent
        case .idle, .needsToken, .failed:
            return DesignTokens.Color.textSecondary
        }
    }

    func message(hasSavedToken: Bool) -> String {
        switch self {
        case .idle:
            return hasSavedToken ? "연결 테스트로 저장소 접근을 확인할 수 있습니다." : "GitHub 연결이 필요합니다."
        case .needsToken:
            return "GitHub 연결이 필요합니다."
        case .saved:
            return "토큰을 저장했습니다."
        case .testing:
            return "연결을 확인하는 중입니다."
        case .connected:
            return "저장소에 접근할 수 있습니다."
        case .rateLimited(let diagnostics):
            if let resetAt = diagnostics?.resetAt {
                return "\(resetAt.formatted(date: .omitted, time: .shortened)) 이후 다시 확인해 주세요."
            }

            return "잠시 후 다시 확인해 주세요."
        case .failed(let failure):
            return failure.message
        }
    }
}
