//
//  GitHubConnectionSettingsView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

struct GitHubConnectionSettingsView: View {
    private let credentialStore = GitHubCredentialStore()
    private let verificationService = GitHubVerificationService()

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
                            .font(.headline)
                    }

                    Text(connectionState.message(hasSavedToken: hasSavedToken))
                        .font(.subheadline)
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
            connectionState = .unavailable
        }
    }

    private func deleteToken() {
        do {
            try credentialStore.deleteToken()
            token = ""
            hasSavedToken = false
            connectionState = .needsToken
        } catch {
            connectionState = .unavailable
        }
    }

    private func testConnection() {
        connectionState = .testing

        Task {
            let result = await verificationService.verify()

            await MainActor.run {
                switch result {
                case .success(let verificationResult):
                    connectionState = verificationResult.hasActivity ? .verified : .connected
                case .failure(.rateLimited(let diagnostics)):
                    connectionState = .rateLimited(diagnostics)
                case .failure:
                    connectionState = .unavailable
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
    case verified
    case rateLimited(GitHubRateLimitDiagnostics?)
    case unavailable

    var tint: Color {
        switch self {
        case .connected, .verified, .saved:
            return DesignTokens.Color.success
        case .rateLimited:
            return DesignTokens.Color.warning
        case .testing:
            return DesignTokens.Color.accent
        case .idle, .needsToken, .unavailable:
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
        case .verified:
            return "오늘의 GitHub 기록을 확인했습니다."
        case .rateLimited(let diagnostics):
            if let resetAt = diagnostics?.resetAt {
                return "\(resetAt.formatted(date: .omitted, time: .shortened)) 이후 다시 확인해 주세요."
            }

            return "잠시 후 다시 확인해 주세요."
        case .unavailable:
            return "연결을 확인하지 못했습니다."
        }
    }
}

#Preview {
    NavigationStack {
        GitHubConnectionSettingsView()
    }
}
