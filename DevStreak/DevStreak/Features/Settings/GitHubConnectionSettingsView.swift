//
//  GitHubConnectionSettingsView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftData
import SwiftUI

struct GitHubConnectionSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRecord.dateKey, order: .reverse) private var records: [DailyRecord]
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    private let credentialStore = GitHubCredentialStore()
    private let repositoryMetadataStore = GitHubRepositoryMetadataStore()
    private let backfillService = GitHubBackfillService()
    private let initialBackfillService = GitHubBackfillService(
        lookbackDays: GitHubVerificationDefaults.initialBackfillLookbackDays,
        authenticatedRequestLimit: GitHubVerificationDefaults.authenticatedInitialBackfillRequestLimit
    )
    private let initialBackfillStore = GitHubInitialBackfillStore()

    @State private var token = ""
    @State private var hasSavedToken = false
    @State private var connectionState = GitHubConnectionState.idle
    @State private var backfillState = GitHubBackfillViewState.idle
    @State private var isBackfillConfirmationPresented = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 16, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(connectionState.tint)

                        Text("GitHub 연결")
                            .font(DesignTokens.Typography.headline)
                    }

                    Text(connectionState.message(hasSavedToken: hasSavedToken))
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
                .padding(.vertical, 2)
            }

            Section {
                if hasSavedToken {
                    Label("토큰이 Keychain에 저장되어 있습니다.", systemImage: "key.fill")
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                } else {
                    SecureField("Fine-grained PAT", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("토큰 저장") {
                        saveToken()
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Button("연결 테스트") {
                    testConnection()
                }
                .disabled(connectionState == .testing)

                if hasSavedToken {
                    Button("토큰 삭제", role: .destructive) {
                        deleteToken()
                    }
                }
            } footer: {
                Text("저장소 확인에는 읽기 권한만 사용하며 토큰은 Keychain에만 저장됩니다.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("과거 기록 동기화")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Color.primaryText)

                    Text("GitHub 기록이 확인된 날짜를 캘린더에 반영합니다.")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)

                Button("최근 30일 동기화") {
                    isBackfillConfirmationPresented = true
                }
                .disabled(backfillState == .syncing)

                if let message = backfillState.message {
                    Text(message)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(backfillState.tint)
                }
            } footer: {
                Text("최초 연결 시 최근 3년의 기록을 자동으로 한 번 동기화합니다. 이후 수동 동기화는 최근 30일 범위로 확인합니다.")
            }
        }
        .navigationTitle("GitHub 연결")
        .font(DesignTokens.Typography.body)
        .task {
            refreshSavedState()
            runInitialBackfillIfNeeded()
        }
        .confirmationDialog(
            "최근 30일의 GitHub 기록을 확인할까요?",
            isPresented: $isBackfillConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("동기화") {
                runBackfill()
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text("GitHub 기록이 확인된 날짜를 완료 기록으로 추가합니다. 기존 기록은 삭제되지 않습니다.")
        }
    }

    private func refreshSavedState() {
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

    private func saveToken() {
        do {
            try credentialStore.saveToken(token)
            token = ""
            hasSavedToken = try credentialStore.hasToken()
            connectionState = hasSavedToken ? .saved : .needsToken
            runInitialBackfillIfNeeded()
        } catch {
            connectionState = .failed(.credentialUnavailable)
        }
    }

    private func deleteToken() {
        do {
            try credentialStore.deleteToken()
            token = ""
            hasSavedToken = false
            connectionState = .needsToken
            initialBackfillStore.reset()
            repositoryMetadataStore.reset()
        } catch {
            connectionState = .failed(.credentialUnavailable)
        }
    }

    private func testConnection() {
        connectionState = .testing

        Task {
            let service = GitHubConnectionTestService(client: GitHubAPIClient())
            let result = await service.testConnection()

            await MainActor.run {
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
            }
        }
    }

    private func runBackfill() {
        runBackfill(service: backfillService, markInitialBackfillCompleted: true)
    }

    private func runInitialBackfillIfNeeded() {
        guard hasSavedToken,
              !initialBackfillStore.hasCompletedInitialBackfill,
              backfillState != .syncing else {
            return
        }

        runBackfill(service: initialBackfillService, markInitialBackfillCompleted: true)
    }

    private func runBackfill(service: GitHubBackfillService, markInitialBackfillCompleted: Bool) {
        backfillState = .syncing

        Task {
            await refreshRepositoryMetadataIfPossible()

            let result = await service.backfill(
                records: records,
                ideas: ideas,
                modelContext: modelContext,
                now: Date()
            )

            await MainActor.run {
                switch result {
                case .success(let backfillResult):
                    if markInitialBackfillCompleted {
                        initialBackfillStore.markCompleted()
                    }

                    backfillState = backfillResult.changedDayCount > 0
                        ? .completed(changedDayCount: backfillResult.changedDayCount)
                        : .completedWithoutChanges
                case .failure(let failure):
                    backfillState = .failed(failure)
                }

                refreshSavedState()
            }
        }
    }

    private func refreshRepositoryMetadataIfPossible() async {
        let service = GitHubConnectionTestService(client: GitHubAPIClient())
        guard case .success(let repository) = await service.testConnection() else {
            return
        }

        repositoryMetadataStore.save(createdAt: repository.createdAt)
    }
}

private struct GitHubInitialBackfillStore {
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

private enum GitHubBackfillViewState: Equatable {
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

private extension GitHubVerificationFailure {
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

private enum GitHubConnectionState: Equatable {
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

nonisolated enum GitHubConnectionFailure: Error, Equatable {
    case invalidToken
    case forbidden
    case repositoryNotFound
    case credentialUnavailable
    case rateLimited(GitHubRateLimitDiagnostics?)
    case networkFailure
    case decodingFailure
    case unknown

    var message: String {
        switch self {
        case .invalidToken:
            return "토큰이 올바르지 않습니다."
        case .forbidden:
            return "GitHub 접근 권한을 확인해 주세요."
        case .repositoryNotFound:
            return "저장소 접근 권한을 확인해 주세요."
        case .credentialUnavailable:
            return "저장된 GitHub 인증 정보를 불러오지 못했습니다."
        case .rateLimited(let diagnostics):
            if let resetAt = diagnostics?.resetAt {
                return "\(resetAt.formatted(date: .omitted, time: .shortened)) 이후 다시 확인해 주세요."
            }

            return "GitHub 요청 한도에 도달했습니다."
        case .networkFailure:
            return "네트워크 연결을 확인해 주세요."
        case .decodingFailure:
            return "GitHub 응답을 처리하지 못했습니다."
        case .unknown:
            return "연결을 확인하지 못했습니다."
        }
    }
}

nonisolated struct GitHubConnectionTestService {
    private let client: GitHubAPIClientProtocol
    private let owner: String
    private let repository: String

    init(
        client: GitHubAPIClientProtocol = GitHubAPIClient(),
        owner: String = GitHubRepositoryConfiguration.owner,
        repository: String = GitHubRepositoryConfiguration.name
    ) {
        self.client = client
        self.owner = owner
        self.repository = repository
    }

    func testConnection() async -> Result<GitHubRepositorySummary, GitHubConnectionFailure> {
        do {
            let repository = try await client.repository(owner: owner, repository: repository)
            return .success(repository)
        } catch let error as GitHubAPIError {
            return .failure(Self.failure(from: error))
        } catch is GitHubCredentialError {
            return .failure(.credentialUnavailable)
        } catch {
            return .failure(.unknown)
        }
    }

    private static func failure(from error: GitHubAPIError) -> GitHubConnectionFailure {
        switch error {
        case .rateLimited(let diagnostics):
            return .rateLimited(diagnostics)
        case .credentialUnavailable:
            return .credentialUnavailable
        case .unauthorized:
            return .invalidToken
        case .forbidden, .unauthorizedOrForbidden:
            return .forbidden
        case .notFound:
            return .repositoryNotFound
        case .networkFailure:
            return .networkFailure
        case .decodingFailure:
            return .decodingFailure
        case .unexpectedStatus:
            return .unknown
        }
    }
}

#Preview {
    NavigationStack {
        GitHubConnectionSettingsView()
    }
}
