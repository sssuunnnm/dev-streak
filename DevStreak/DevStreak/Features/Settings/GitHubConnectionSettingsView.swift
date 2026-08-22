//
//  GitHubConnectionSettingsView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

struct GitHubConnectionSettingsView: View {
    private let credentialStore = GitHubCredentialStore()

    @State private var token = ""
    @State private var hasSavedToken = false
    @State private var connectionState = GitHubConnectionState.idle

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
                SecureField("Fine-grained PAT", text: $token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("토큰 저장") {
                    saveToken()
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
                Text("sssuunnnm/dev-archive 읽기 권한만 사용합니다. 토큰은 Keychain에만 저장됩니다.")
            }
        }
        .navigationTitle("GitHub 연결")
        .font(DesignTokens.Typography.body)
        .task {
            refreshSavedState()
        }
    }

    private func refreshSavedState() {
        hasSavedToken = credentialStore.hasToken()
        if !hasSavedToken, connectionState == .idle {
            connectionState = .needsToken
        }
    }

    private func saveToken() {
        do {
            try credentialStore.saveToken(token)
            token = ""
            hasSavedToken = credentialStore.hasToken()
            connectionState = hasSavedToken ? .saved : .needsToken
        } catch {
            connectionState = .failed(.unknown)
        }
    }

    private func deleteToken() {
        do {
            try credentialStore.deleteToken()
            token = ""
            hasSavedToken = false
            connectionState = .needsToken
        } catch {
            connectionState = .failed(.unknown)
        }
    }

    private func testConnection() {
        connectionState = .testing

        Task {
            let service = GitHubConnectionTestService(client: GitHubAPIClient())
            let result = await service.testConnection()

            await MainActor.run {
                switch result {
                case .success:
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
            return hasSavedToken ? "토큰이 저장되어 있습니다." : "GitHub 연결이 필요합니다."
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

enum GitHubConnectionFailure: Error, Equatable {
    case invalidToken
    case forbidden
    case repositoryNotFound
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
            return "dev-archive 저장소 접근 권한을 확인해 주세요."
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

struct GitHubConnectionTestService {
    private let client: GitHubAPIClientProtocol
    private let owner: String
    private let repository: String

    init(
        client: GitHubAPIClientProtocol = GitHubAPIClient(),
        owner: String = "sssuunnnm",
        repository: String = "dev-archive"
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
        } catch {
            return .failure(.unknown)
        }
    }

    private static func failure(from error: GitHubAPIError) -> GitHubConnectionFailure {
        switch error {
        case .rateLimited(let diagnostics):
            return .rateLimited(diagnostics)
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
