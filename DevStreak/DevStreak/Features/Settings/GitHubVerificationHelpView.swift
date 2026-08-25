//
//  GitHubVerificationHelpView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

struct GitHubVerificationHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let items = [
        "GitHub Settings > Developer settings > Personal access tokens > Fine-grained tokens에서 새 token을 만듭니다.",
        "Repository access는 확인할 저장소만 선택합니다.",
        "Repository permissions는 Contents: Read-only, Pull requests: Read-only만 허용하면 됩니다.",
        "생성한 token을 복사해 GitHub 연결 설정에 저장합니다.",
        "token은 Keychain에만 저장되고 GitHub API Authorization header에만 사용됩니다.",
        "DevStreak는 저장소를 수정하거나 commit, PR을 생성하지 않습니다.",
        "네트워크 오류나 GitHub API 확인 실패는 오늘 미작성으로 처리하지 않습니다."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GitHub 기록 확인이란?")
                        .font(DesignTokens.Typography.title3)
                        .foregroundStyle(DesignTokens.Color.primaryText)

                    Text("GitHub 기록을 읽기 전용으로 확인해 오늘 상태에 반영하는 기능입니다.")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }

                Divider()
                    .overlay(DesignTokens.Color.hairline)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignTokens.Color.accent)
                                .padding(.top, 3)

                            Text(item)
                                .font(DesignTokens.Typography.body)
                                .foregroundStyle(DesignTokens.Color.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                NavigationLink {
                    GitHubConnectionSettingsView()
                } label: {
                    HStack(spacing: 8) {
                        Text("GitHub 연결 설정")
                            .font(DesignTokens.Typography.footnote)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DesignTokens.Color.accent)
                }
            }
            .padding(DesignTokens.Spacing.page)
        }
        .background(Color(.systemBackground))
        .navigationTitle("도움말")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") {
                    dismiss()
                }
                .font(DesignTokens.Typography.body)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GitHubVerificationHelpView()
    }
}
