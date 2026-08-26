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

    @StateObject private var coordinator = GitHubConnectionCoordinator()
    @State private var token = ""
    @State private var isBackfillConfirmationPresented = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 16, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(coordinator.connectionState.tint)

                        Text("GitHub 연결")
                            .font(DesignTokens.Typography.headline)
                    }

                    Text(coordinator.connectionState.message(hasSavedToken: coordinator.hasSavedToken))
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
                .padding(.vertical, 2)
            }

            Section {
                if coordinator.hasSavedToken {
                    Label("토큰이 Keychain에 저장되어 있습니다.", systemImage: "key.fill")
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                } else {
                    SecureField("Fine-grained PAT", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("토큰 저장") {
                        coordinator.saveToken(
                            token,
                            records: records,
                            ideas: ideas,
                            modelContext: modelContext
                        )
                        token = ""
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Button("연결 테스트") {
                    coordinator.testConnection()
                }
                .disabled(coordinator.connectionState == .testing)

                if coordinator.hasSavedToken {
                    Button("토큰 삭제", role: .destructive) {
                        coordinator.deleteToken(records: records, ideas: ideas, modelContext: modelContext)
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
                .disabled(coordinator.backfillState == .syncing)

                if let message = coordinator.backfillState.message {
                    Text(message)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(coordinator.backfillState.tint)
                }
            } footer: {
                Text("최초 연결 시 최근 3년의 기록을 자동으로 한 번 동기화합니다. 이후 수동 동기화는 최근 30일 범위로 확인합니다.")
            }
        }
        .navigationTitle("GitHub 연결")
        .font(DesignTokens.Typography.body)
        .task {
            coordinator.refreshSavedState()
            coordinator.runInitialBackfillIfNeeded(
                records: records,
                ideas: ideas,
                modelContext: modelContext
            )
        }
        .confirmationDialog(
            "최근 30일의 GitHub 기록을 확인할까요?",
            isPresented: $isBackfillConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("동기화") {
                coordinator.runManualBackfill(
                    records: records,
                    ideas: ideas,
                    modelContext: modelContext
                )
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text("GitHub 기록이 확인된 날짜를 완료 기록으로 추가합니다. 기존 기록은 삭제되지 않습니다.")
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
